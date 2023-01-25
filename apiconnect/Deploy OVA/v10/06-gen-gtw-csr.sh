#!/bin/bash
# ===========================================================================
# This script
# ===========================================================================
if [ -z "$1" ]; then
    echo "Syntax:"
    echo "  Provide configuration filename as a parameter"
    exit
fi

if [ ! -f ./$1 ]; then
    echo "Configuration file $1 not found, aborting."
    exit
fi

# . ./00-env.conf
cd $PROJECT_DIR
mkdir $KEYS_DIR
cd $KEYS_DIR

echo "================================================================================"
echo "Generating keys for the Gateway service"
echo "================================================================================"
if [[ -f $GTW_PRIVKEY ]]; then
echo Private key file $GTW_PRIVKEY already exists... Skipping key pair and csr generation...
else


cat << EOF > $GTW_CONF
[req]
# default key length for rsa key
default_bits = 2048

# do not encrypt private key
encrypt_key = no
encrypt_rsa_key = no

# default message digest alg for signing certs and cert reqs
default_md = sha256

# cert request extensions section
req_extensions = req_ext

# self-signed cert extensions section
x509_extensions = req_ext

# do not prompt for the dn
prompt = no

# section name for dn fields
distinguished_name = dn

# make sure dn components match ca policy
[dn]
C  = $KEYS_COUNTRY
ST = $KEYS_STATE
L  = $KEYS_LOCALITY
O  = $KEYS_ORGANIZATION
OU = $KEYS_ORGANIZATIONAL_UNIT
CN = $DP_GW_ENDPOINT_AI

[req_ext]
# basicConstraints = critical
keyUsage = critical, digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth,clientAuth
subjectKeyIdentifier = hash
# subjectAltName = @alt_names
subjectAltName = DNS:$DP_GW_ENDPOINT_AI,DNS:$DP_GWD_ENDPOINT_AI,DNS:$DP_SERVER1_MGMT_HOSTNAME

# [alt_names]
# DNS.1 = $DP_GW_ENDPOINT_AI
# DNS.2 = $DP_GWD_ENDPOINT_AI
# DNS.3 = $DP_SERVER1_MGMT_HOSTNAME
EOF

openssl req -config $GTW_CONF -out $GTW_CSR -outform PEM -new -keyout $GTW_PRIVKEY
openssl req -x509 -days $KEYS_CERT_DAYS -config $GTW_CONF -out $GTW_SSCERT -outform PEM -new -key $GTW_PRIVKEY

fi
