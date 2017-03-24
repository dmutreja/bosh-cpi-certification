#!/usr/bin/env bash

set -e

source pipelines/shared/utils.sh

: ${BOSH_VSPHERE_VCENTER:?}
: ${BOSH_VSPHERE_VCENTER_USER:?}
: ${BOSH_VSPHERE_VCENTER_PASSWORD:?}
: ${BOSH_VSPHERE_VERSION:?}
: ${BOSH_VSPHERE_VCENTER_DC:?}
: ${BOSH_VSPHERE_VCENTER_CLUSTER:?}
: ${BOSH_VSPHERE_VCENTER_VM_FOLDER:?}
: ${BOSH_VSPHERE_VCENTER_TEMPLATE_FOLDER:?}
: ${BOSH_VSPHERE_VCENTER_DATASTORE:?}
: ${BOSH_VSPHERE_VCENTER_DISK_PATH:?}
: ${BOSH_VSPHERE_VCENTER_VLAN:?}
: ${BOSH_CLIENT:?}
: ${BOSH_CLIENT_SECRET:?}
: ${USE_REDIS:=false}
: ${SSLIP_IO_CREDS:?}

# inputs
# paths will be resolved in a separate task so use relative paths
BOSH_RELEASE_URI="file://$(echo bosh-release/*.tgz)"
CPI_RELEASE_URI="file://$(echo cpi-release/*.tgz)"
STEMCELL_URI="file://$(echo stemcell/*.tgz)"

# outputs
output_dir="$(realpath director-config)"

bosh_cli=$(realpath bosh-cli/*bosh-cli-*)
chmod +x $bosh_cli

# environment
env_name=$(cat environment/name)
metadata=$(cat environment/metadata)
network1=$(env_attr "${metadata}" "network1")
echo Using environment: \'${env_name}\'
: ${DIRECTOR_IP:=$(                  env_attr "${metadata}" "directorIP" )}
: ${BOSH_VSPHERE_VCENTER_CIDR:=$(    env_attr "${network1}" "vCenterCIDR" )}
: ${BOSH_VSPHERE_VCENTER_GATEWAY:=$( env_attr "${network1}" "vCenterGateway" )}
: ${BOSH_VSPHERE_DNS:=$(             env_attr "${metadata}" "DNS" )}

redis_job=""
if [ "${USE_REDIS}" == true ]; then
  redis_job="- {name: redis, release: bosh}"
fi

# env file generation
cat > "${output_dir}/director.env" <<EOF
#!/usr/bin/env bash

export BOSH_ENVIRONMENT="${DIRECTOR_IP//./-}.sslip.io"
export BOSH_CLIENT=${BOSH_CLIENT}
export BOSH_CLIENT_SECRET=${BOSH_CLIENT_SECRET}
EOF

cat > /tmp/director-template.yml <<EOF
---
name: certification-director

releases:
  - name: bosh
    url: ((bosh_release_uri))
  - name: bosh-vsphere-cpi
    url: ((cpi_release_uri))

resource_pools:
  - name: vms
    network: private
    stemcell:
      url: ((stemcell_uri))
    cloud_properties:
      cpu: 2
      ram: 4_096
      disk: 20_000

disk_pools:
  - name: disks
    disk_size: 20_000
    cloud_properties:
      datastores: [((bosh_vsphere_vcenter_datastore))]

networks:
  - name: private
    type: manual
    subnets:
      - range: ((bosh_vsphere_vcenter_cidr))
        gateway: ((bosh_vsphere_vcenter_gateway))
        dns: [((bosh_vsphere_dns))]
        cloud_properties: {name: ((bosh_vsphere_vcenter_vlan))}

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
      - {name: vsphere_cpi, release: bosh-vsphere-cpi}
      ${redis_job}

    resource_pool: vms
    persistent_disk_pool: disks

    networks:
      - {name: private, static_ips: [((director_ip))]}

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

      blobstore:
        address: ((director_ip))
        port: 25250
        provider: dav
        director: {user: director, password: director-password}
        agent: {user: agent, password: agent-password}

      director:
        address: 127.0.0.1
        name: certification-director
        db: *db
        cpi_job: vsphere_cpi
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
        resurrector_enabled: true

      agent: {mbus: "nats://nats:nats-password@((director_ip)):4222"}

      dns:
        address: 127.0.0.1
        db: *db

      vcenter: &vcenter
        address: ((bosh_vsphere_vcenter))
        user: ((bosh_vsphere_vcenter_user))
        password: ((bosh_vsphere_vcenter_password))
        datacenters:
          - name: ((bosh_vsphere_vcenter_dc))
            vm_folder: ((bosh_vsphere_vcenter_vm_folder))
            template_folder: ((bosh_vsphere_vcenter_template_folder))
            datastore_pattern: ((bosh_vsphere_vcenter_datastore))
            persistent_datastore_pattern: ((bosh_vsphere_vcenter_datastore))
            disk_path: ((bosh_vsphere_vcenter_disk_path))
            clusters: [((bosh_vsphere_vcenter_cluster))]

cloud_provider:
  template: {name: vsphere_cpi, release: bosh-vsphere-cpi}

  mbus: "https://mbus:mbus-password@((director_ip)):6868"

  properties:
    vcenter: *vcenter
    agent: {mbus: "https://mbus:mbus-password@0.0.0.0:6868"}
    blobstore: {provider: local, path: /var/vcap/micro_bosh/data/cache}
    ntp: [0.pool.ntp.org, 1.pool.ntp.org]
EOF

$bosh_cli interpolate \
  -v bosh_release_uri="${BOSH_RELEASE_URI}" \
  -v cpi_release_uri="${CPI_RELEASE_URI}" \
  -v stemcell_uri="${STEMCELL_URI}" \
  -v bosh_vsphere_vcenter_datastore="${BOSH_VSPHERE_VCENTER_DATASTORE}" \
  -v bosh_vsphere_vcenter_cidr="${BOSH_VSPHERE_VCENTER_CIDR}" \
  -v bosh_vsphere_vcenter_gateway="${BOSH_VSPHERE_VCENTER_GATEWAY}" \
  -v bosh_vsphere_vcenter_vlan="${BOSH_VSPHERE_VCENTER_VLAN}" \
  -v bosh_vsphere_dns="${BOSH_VSPHERE_DNS}" \
  -v director_ip="${DIRECTOR_IP}" \
  -v bosh_client="${BOSH_CLIENT}" \
  -v bosh_client_secret="${BOSH_CLIENT_SECRET}" \
  -v bosh_vsphere_vcenter="${BOSH_VSPHERE_VCENTER}" \
  -v bosh_vsphere_vcenter_user="${BOSH_VSPHERE_VCENTER_USER}" \
  -v bosh_vsphere_vcenter_password="${BOSH_VSPHERE_VCENTER_PASSWORD}" \
  -v bosh_vsphere_vcenter_dc="${BOSH_VSPHERE_VCENTER_DC}" \
  -v bosh_vsphere_vcenter_vm_folder="${BOSH_VSPHERE_VCENTER_VM_FOLDER}" \
  -v bosh_vsphere_vcenter_template_folder="${BOSH_VSPHERE_VCENTER_TEMPLATE_FOLDER}" \
  -v bosh_vsphere_vcenter_datastore="${BOSH_VSPHERE_VCENTER_DATASTORE}" \
  -v bosh_vsphere_vcenter_disk_path="${BOSH_VSPHERE_VCENTER_DISK_PATH}" \
  -v bosh_vsphere_vcenter_cluster="${BOSH_VSPHERE_VCENTER_CLUSTER}" \
  -l <(echo "$SSLIP_IO_CREDS") \
  /tmp/director-template.yml > "${output_dir}/director.yml"
