#!/usr/bin/env bash

set -e

# environment
: ${BOSH_CLIENT:?}
: ${BOSH_CLIENT_SECRET:?}
: ${AWS_ACCESS_KEY:?}
: ${AWS_SECRET_KEY:?}
: ${AWS_REGION_NAME:?}
: ${AWS_STACK_NAME:?}
: ${PUBLIC_KEY_NAME:?}
: ${PRIVATE_KEY_DATA:?}
: ${SSLIP_IO_CREDS:?}
: ${USE_REDIS:=false}

# inputs
# paths will be resolved in a separate task so use relative paths
BOSH_RELEASE_URI="file://$(echo bosh-release/*.tgz)"
CPI_RELEASE_URI="file://$(echo cpi-release/*.tgz)"
STEMCELL_URI="file://$(echo stemcell/*.tgz)"

# outputs
output_dir="$(realpath director-config)"

bosh_cli=$(realpath bosh-cli/*bosh-cli-*)
chmod +x $bosh_cli

source pipelines/shared/utils.sh
source pipelines/aws/utils.sh

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_KEY}
export AWS_DEFAULT_REGION=${AWS_REGION_NAME}

# configuration
: ${SECURITY_GROUP:=$(       aws ec2 describe-security-groups --group-ids $(stack_info "SecurityGroupID") | jq -r '.SecurityGroups[] .GroupName' )}
: ${DIRECTOR_EIP:=$(         stack_info "DirectorEIP" )}
: ${SUBNET_ID:=$(            stack_info "PublicSubnetID" )}
: ${AVAILABILITY_ZONE:=$(    stack_info "AvailabilityZone" )}
: ${AWS_NETWORK_CIDR:=$(     stack_info "PublicCIDR" )}
: ${AWS_NETWORK_GATEWAY:=$(  stack_info "PublicGateway" )}
: ${AWS_NETWORK_DNS:=$(      stack_info "DNS" )}
: ${DIRECTOR_STATIC_IP:=$(   stack_info "DirectorStaticIP" )}
: ${BLOBSTORE_BUCKET_NAME:=$(stack_info "BlobstoreBucketName")}

# keys
shared_key="shared.pem"
echo "${PRIVATE_KEY_DATA}" > "${output_dir}/${shared_key}"

redis_job=""
if [ "${USE_REDIS}" == true ]; then
  redis_job="- {name: redis, release: bosh}"
fi

# env file generation
cat > "${output_dir}/director.env" <<EOF
#!/usr/bin/env bash

export BOSH_ENVIRONMENT="${DIRECTOR_EIP//./-}.sslip.io"
export BOSH_CLIENT=${BOSH_CLIENT}
export BOSH_CLIENT_SECRET=${BOSH_CLIENT_SECRET}
EOF

# manifest generation
cat > /tmp/director-template.yml <<EOF
---
name: certification-director

releases:
  - name: bosh
    url: ((bosh_release_uri))
  - name: bosh-aws-cpi
    url: ((cpi_release_uri))

resource_pools:
  - name: default
    network: private
    stemcell:
      url: ((stemcell_uri))
    cloud_properties:
      instance_type: m3.medium
      availability_zone: ((availability_zone))
      ephemeral_disk:
        size: 25000
        type: gp2

disk_pools:
  - name: default
    disk_size: 25_000
    cloud_properties: {type: gp2}

networks:
  - name: private
    type: manual
    subnets:
    - range:    ((aws_network_cidr))
      gateway:  ((aws_network_gateway))
      dns:      [8.8.8.8]
      cloud_properties: {subnet: ((subnet_id))}
  - name: public
    type: vip

jobs:
  - name: bosh
    instances: 1

    templates:
      - {name: nats, release: bosh}
      - {name: postgres, release: bosh}
      - {name: blobstore, release: bosh}
      - {name: director, release: bosh}
      - {name: health_monitor, release: bosh}
      - {name: powerdns, release: bosh}
      - {name: registry, release: bosh}
      - {name: aws_cpi, release: bosh-aws-cpi}
      ${redis_job}

    resource_pool: default
    persistent_disk_pool: default

    networks:
      - name: private
        static_ips: [((director_static_ip))]
        default: [dns, gateway]
      - name: public
        static_ips: [((director_eip))]

    properties:
      nats:
        address: 127.0.0.1
        user: nats
        password: nats-password

      postgres: &db
        host: 127.0.0.1
        user: postgres
        password: postgres-password
        database: bosh
        adapter: postgres

      # required for some upgrade paths
      redis:
        listen_addresss: 127.0.0.1
        address: 127.0.0.1
        password: redis-password

      registry:
        address: ((director_static_ip))
        host: ((director_static_ip))
        db: *db
        http: {user: ((bosh_client)), password: ((bosh_client_secret)), port: 25777}
        username: ((bosh_client))
        password: ((bosh_client_secret))
        port: 25777

      blobstore:
        director: {user: director, password: director-password}
        agent: {user: agent, password: agent-password}
        provider: s3
        s3_region: ((aws_region_name))
        bucket_name: ((blobstore_bucket_name))
        s3_signature_version: '4'
        access_key_id: $((aws_access_key))
        secret_access_key: ((aws_secret_key))

      director:
        address: 127.0.0.1
        name: bats-director
        db: *db
        cpi_job: aws_cpi
        user_management:
          provider: local
          local:
            users:
              - {name: ((bosh_client)), password: ((bosh_client_secret))}
        ssl:
          key: ((sslip_io_key))
          cert: ((sslip_io_cert))

      hm:
        http: {user: hm, password: hm-password}
        director_account: {user: ((bosh_client)), password: ((bosh_client_secret))}

      dns:
        recursor: 10.0.0.2
        address: 127.0.0.1
        db: *db

      agent: {mbus: "nats://nats:nats-password@((director_static_ip)):4222"}

      ntp: &ntp
        - 0.north-america.pool.ntp.org
        - 1.north-america.pool.ntp.org

      aws: &aws-config
        default_key_name: ((public_key_name))
        default_security_groups: [((security_group))]
        region: ((aws_region_name))
        access_key_id: ((aws_access_key))
        secret_access_key: ((aws_secret_key))

cloud_provider:
  template: {name: aws_cpi, release: bosh-aws-cpi}

  ssh_tunnel:
    host: ((director_eip))
    port: 22
    user: vcap
    private_key: ((shared_key))

  mbus: "https://mbus:mbus-password@((director_eip)):6868"

  properties:
    aws: *aws-config

    # Tells CPI how agent should listen for requests
    agent: {mbus: "https://mbus:mbus-password@0.0.0.0:6868"}

    blobstore:
      provider: local
      path: /var/vcap/micro_bosh/data/cache

    ntp: *ntp
EOF

$bosh_cli interpolate \
  -v bosh_release_uri="${BOSH_RELEASE_URI}" \
  -v cpi_release_uri="${CPI_RELEASE_URI}" \
  -v stemcell_uri="${STEMCELL_URI}" \
  -v availability_zone="${AVAILABILITY_ZONE}" \
  -v aws_network_cidr="${AWS_NETWORK_CIDR}" \
  -v subnet_id="${SUBNET_ID}" \
  -v aws_network_gateway="${AWS_NETWORK_GATEWAY}" \
  -v director_static_ip="${DIRECTOR_STATIC_IP}" \
  -v director_eip="${DIRECTOR_EIP}" \
  -v bosh_client="${BOSH_CLIENT}" \
  -v bosh_client_secret="${BOSH_CLIENT_SECRET}" \
  -v blobstore_bucket_name="${BLOBSTORE_BUCKET_NAME}" \
  -v aws_region_name="${AWS_REGION_NAME}" \
  -l <(echo "$SSLIP_IO_CREDS") \
  -v public_key_name="${PUBLIC_KEY_NAME}" \
  -v security_group="${SECURITY_GROUP}" \
  -v aws_access_key="${AWS_ACCESS_KEY}" \
  -v aws_secret_key="${AWS_SECRET_KEY}" \
  -v aws_access_key="${AWS_ACCESS_KEY}" \
  -v shared_key="${shared_key}" \
  /tmp/director-template.yml > "${output_dir}/director.yml"
