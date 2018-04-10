#!/bin/sh

set -e

# Output
pwd=`pwd`
vars_dir=${pwd}/terraform-vars
mkdir -p ${vars_dir}

vars_file=${vars_dir}/oci.vars
key_relative_path=terraform-vars/oci_api_key.pem


echo "Creating terraform variables file..."

cat > ${key_relative_path} <<EOF
${oracle_apikey}
EOF
chmod 600 ${key_relative_path}

cat > ${vars_file} <<EOF
oracle_private_key_path: ${key_relative_path}
EOF

echo "Done. Created: " ${vars_file}