#!/usr/bin/env bash

set -e

: ${VCLOUD_VLAN:?}
: ${VCLOUD_HOST:?}
: ${VCLOUD_USER:?}
: ${VCLOUD_PASSWORD:?}
: ${VCLOUD_ORG:?}
: ${VCLOUD_VDC:?}
: ${VCLOUD_VAPP:?}
: ${VCLOUD_CATALOG:?}
: ${NETWORK_CIDR:?}
: ${NETWORK_GATEWAY:?}
: ${BATS_DIRECTOR_IP:?}
: ${BOSH_CLIENT:?}
: ${BOSH_CLIENT_SECRET:?}
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

# env file generation
cat > "${output_dir}/director.env" <<EOF
#!/usr/bin/env bash

export BOSH_ENVIRONMENT="${BATS_DIRECTOR_IP//./-}.sslip.io"
export BOSH_CLIENT=${BOSH_CLIENT}
export BOSH_CLIENT_SECRET=${BOSH_CLIENT_SECRET}
EOF

cat > /tmp/director-template.yml <<EOF
---
name: certification-director

releases:
  - name: bosh
    url: ((bosh_release_uri))
    sha1: ((bosh_release_sha1))
  - name: bosh-vcloud-cpi
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
    env:
      vapp: ((vcloud_vapp))

disk_pools:
  - name: disks
    disk_size: 20_000

networks:
  - name: private
    type: manual
    subnets:
      - range: ((network_cidr))
        gateway: ((network_gateway))
        dns: [8.8.8.8]
        cloud_properties: {name: ((vcloud_vlan))}

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
      - {name: vcloud_cpi, release: bosh-vcloud-cpi}

    resource_pool: vms
    persistent_disk_pool: disks

    networks:
      - {name: private, static_ips: [((bats_director_ip))]}

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

      blobstore:
        address: ((bats_director_ip))
        port: 25250
        provider: dav
        director: {user: director, password: director-password}
        agent: {user: agent, password: agent-password}

      director:
        address: 127.0.0.1
        name: certification-director
        db: *db
        cpi_job: vcloud_cpi
        max_threads: 10
        user_management:
          provider: local
          local:
            users:
              - {name: ((bosh_client)), password: ((bosh_client_secret))}
        ssl:
          key: ((sslip_io_key))
          cert: ((sslip_io_cert))

      vcd: &vcd
        url: ((vcloud_host))
        user: ((vcloud_user))
        password: ((vcloud_password))
        entities:
          organization: ((vcloud_org))
          virtual_datacenter: ((vcloud_vdc))
          vapp_catalog: ((vcloud_catalog))
          media_catalog: ((vcloud_catalog))
          media_storage_profile: '*'
          vm_metadata_key: vm-metadata-key
        control: {wait_max: 900}

      hm:
        http: {user: hm, password: hm-password}
        director_account: {user: admin, password: admin}
        resurrector_enabled: true

      dns:
        address: 127.0.0.1
        db: *db

      agent: {mbus: "nats://nats:nats-password@((bats_director_ip)):4222"}

      ntp: &ntp [0.pool.ntp.org, 1.pool.ntp.org]

cloud_provider:
  template: {name: vcloud_cpi, release: bosh-vcloud-cpi}

  mbus: "https://mbus:mbus-password@((bats_director_ip)):6868"

  properties:
    vcd: *vcd
    agent: {mbus: "https://mbus:mbus-password@0.0.0.0:6868"}
    blobstore: {provider: local, path: /var/vcap/micro_bosh/data/cache}
    ntp: *ntp
EOF

$bosh_cli interpolate \
  -v bosh_release_uri="${BOSH_RELEASE_URI}" \
  -v bosh_release_sha1="${BOSH_RELEASE_SHA1}" \
  -v cpi_release_uri="${CPI_RELEASE_URI}" \
  -v stemcell_uri="${STEMCELL_URI}" \
  -v vcloud_vapp="${VCLOUD_VAPP}" \
  -v network_cidr="${NETWORK_CIDR}" \
  -v network_gateway="${NETWORK_GATEWAY}" \
  -v network_vlan="${NETWORK_VLAN}" \
  -v bats_director_ip="${BATS_DIRECTOR_IP}" \
  -v bosh_client="${BOSH_CLIENT}" \
  -v bosh_client_secret="${BOSH_CLIENT_SECRET}" \
  -v vcloud_host="${VCLOUD_HOST}" \
  -v vcloud_user="${VCLOUD_USER}" \
  -v vcloud_catalog="${VCLOUD_CATALOG}" \
  -v vcloud_password="${VCLOUD_PASSWORD}" \
  -v vcloud_org="${VCLOUD_ORG}" \
  -v vcloud_vdc="${VCLOUD_VDC}" \
  -l <(echo "$SSLIP_IO_CREDS") \
  /tmp/director-template.yml > "${output_dir}/director.yml"
