#!/bin/sh

set -e

# Outpout
pwd=`pwd`
vars_dir=${pwd}/terraform-vars
mkdir -p ${vars_dir}

api_key_path=${vars_dir}/oci_api_key.pem

vars_file=${vars_dir}/oci.vars


echo "Creating terraform variables file..."

cat > ${api_key_path} <<EOF
${oracle_apikey}
EOF
chmod 600 ${api_key_path}

cat > ${vars_file} <<EOF
oracle_private_key_path: ${api_key_path}
EOF

echo "Done. Created: " ${vars_file}