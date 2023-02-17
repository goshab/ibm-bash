#!/bin/bash
# ===========================================================================
# Support: standalone v10.0.5.1 on OVA
# ===========================================================================
# 
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

cd $PROJECT_DIR
echo "================================================================================"
echo "Configuring the "$PTL_APIC_SUBSYSTEM_NAME" service"
echo "================================================================================"
../../apicup subsys create port $PTL_APIC_SUBSYSTEM_NAME
../../apicup subsys set port deployment-profile $PTL_APIC_DEPLOYMENT_PROFILE
../../apicup subsys set port license-use $APIC_LICENSE

../../apicup subsys set port search-domain $PTL_SEARCH_DOMAIN
../../apicup subsys set port dns-servers=$PTL_DNS_SERVERS

../../apicup subsys set port portal-admin $PTL_ENDPOINT_ADMIN
../../apicup subsys set port portal-www $PTL_ENDPOINT_PORTAL

../../apicup subsys set port ssh-keyfiles $VM_APICADM_SSH_KEY_FILENAME.pub
../../apicup subsys set port default-password $VM_APICADM_PASSWORD_HASHED

../../apicup hosts create port $PTL_VM1_HOST $VM_HD_PASSWORD
../../apicup iface create port $PTL_VM1_HOST eth0 $PTL_VM1_IP/$PTL_VM1_SUBNET_MASK $PTL_VM1_DEFAULT_GATEWAY

# ../../apicup subsys set port cassandra-backup-protocol=objstore
# ../../apicup subsys set port cassandra-backup-host=s3.us-south.cloud-object-storage.appdomain.cloud/us-south
# ../../apicup subsys set port cassandra-backup-auth-user=$PTL_BACKUP_USERNAME
# ../../apicup subsys set port cassandra-backup-auth-pass=$PTL_BACKUP_PASSWORD
# ../../apicup subsys set port cassandra-backup-path=$PTL_BACKUP_PATH
# ../../apicup subsys set port cassandra-backup-schedule="0 0 * * 0"
echo "================================================================================"
echo "Validating the service configuration"
echo "================================================================================"
../../apicup subsys get port --validate
echo "================================================================================"
