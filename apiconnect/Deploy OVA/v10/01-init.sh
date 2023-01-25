#!/bin/bash
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

../apicup init $PROJECT_DIR
cd $PROJECT_DIR

../../apicup licenses accept $APIC_LICENSE_ID
ssh-keygen -t rsa -C "API Connect VM ssh login key" -q -N "" -f $VM_APICADM_SSH_KEY_FILENAME

echo "ssh -l apicadm -i $VM_APICADM_SSH_KEY_FILENAME $MGMT_VM1_HOST" > $MGMT_VM1_HOST.sh
chmod +x $MGMT_VM1_HOST.sh

echo "ssh -l apicadm -i $VM_APICADM_SSH_KEY_FILENAME $PTL_VM1_HOST" > $PTL_VM1_HOST.sh
chmod +x $PTL_VM1_HOST.sh

echo "ssh -l apicadm -i $VM_APICADM_SSH_KEY_FILENAME $A7S_VM1_HOST" > $A7S_VM1_HOST.sh
chmod +x $A7S_VM1_HOST.sh

mkdir $KEYS_DIR
cd $KEYS_DIR

if [ -z "$ROOTCA_CN" ]; then 
  echo "Skipping Root CA keys generation"
else
    echo "Generation Root CA keys"

cat << EOF > $ROOTCA_CONF
[req]
prompt = no
encrypt_key = no
encrypt_rsa_key = no
# req_extensions = req_ext
x509_extensions = req_ext
distinguished_name = dn

[req_ext]
authorityKeyIdentifier = keyid
# authorityKeyIdentifier = issuer
basicConstraints = critical,CA:TRUE
keyUsage = keyCertSign, cRLSign
subjectKeyIdentifier = hash

[dn]
C  = $KEYS_COUNTRY
ST = $KEYS_STATE
L  = $KEYS_LOCALITY
O  = $KEYS_ORGANIZATION
OU = $KEYS_ORGANIZATIONAL_UNIT
CN = $ROOTCA_CN
EOF

    openssl genrsa -out $ROOTCA_PRIVKEY 4096
    openssl req -x509 -sha256 -new -nodes -config $ROOTCA_CONF -key $ROOTCA_PRIVKEY -days 3650 -out $ROOTCA_CERT -outform PEM
    # -subj "/CN=$ROOTCA_CN"
fi;
