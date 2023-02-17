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

. $1

cd $PROJECT_DIR/$KEYS_DIR

echo "================================================================================"
echo "Generating keys for the Gateway service"
echo "================================================================================"
if [[ -f $GTW_PRIVKEY ]]; then
echo Private key file $GTW_PRIVKEY already exists. Skipping keys generation.
exit
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
basicConstraints = critical,CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth,clientAuth
subjectKeyIdentifier = hash
subjectAltName = DNS:$DP_GW_ENDPOINT_AI,DNS:$DP_GWD_ENDPOINT_AI,DNS:$DP_SERVER1_MGMT_HOSTNAME
EOF

echo "Generating CSR"
openssl req -config $GTW_CONF -out $GTW_CSR -outform PEM -new -keyout $GTW_PRIVKEY

if [ -z "$ROOTCA_CN" ]; then 
    echo "Generating self-signed certificate"
    openssl req -x509 -days $KEYS_CERT_DAYS -config $GTW_CONF -out $GTW_SSCERT -outform PEM -new -key $GTW_PRIVKEY
else
    echo "Signing on the CSR with a local CA"

cat << EOF > $GTW_EXT
basicConstraints = CA:FALSE
authorityKeyIdentifier = keyid
# authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature, keyEncipherment, dataEncipherment
# keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectKeyIdentifier = hash
subjectAltName = DNS:$DP_GW_ENDPOINT_AI,DNS:$DP_GWD_ENDPOINT_AI,DNS:$DP_SERVER1_MGMT_HOSTNAME
EOF

    openssl x509 -req -days $KEYS_CERT_DAYS -in $GTW_CSR -CA $ROOTCA_CERT -out $GTW_CERT -sha256 -extfile $GTW_EXT -CAkey $ROOTCA_PRIVKEY -CAcreateserial 
fi;

cat $ROOTCA_CERT $GTW_CERT > $GTW_BUNDLE
fi;



