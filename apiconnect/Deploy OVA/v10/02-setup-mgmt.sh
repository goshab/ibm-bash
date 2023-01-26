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
echo "Configuring the "$MGMT_APIC_SUBSYSTEM_NAME" service"
echo "================================================================================"
# set -x
# ../../apicup licenses accept $APIC_LICENSE_ID
../../apicup subsys create mgmt $MGMT_APIC_SUBSYSTEM_NAME
../../apicup subsys set mgmt deployment-profile=$MGMT_APIC_DEPLOYMENT_PROFILE
../../apicup subsys set mgmt license-use=$APIC_LICENSE
# set +x
# exit
../../apicup subsys set mgmt search-domain=$MGMT_SEARCH_DOMAIN
../../apicup subsys set mgmt dns-servers=$MGMT_DNS_SERVERS

../../apicup subsys set mgmt cloud-admin-ui=$MGMT_ENDPOINT_CM
../../apicup subsys set mgmt api-manager-ui=$MGMT_ENDPOINT_APIM
../../apicup subsys set mgmt platform-api=$MGMT_ENDPOINT_PLATFORM_API
../../apicup subsys set mgmt consumer-api=$MGMT_ENDPOINT_CONSUMER_API
../../apicup subsys set mgmt hub $MGMT_ENDPOINT_HUB
../../apicup subsys set mgmt turnstile $MGMT_ENDPOINT_TURNSTILE

../../apicup subsys set mgmt default-password=$VM_APICADM_PASSWORD_HASHED
../../apicup subsys set mgmt ssh-keyfiles=$VM_APICADM_SSH_KEY_FILENAME.pub

../../apicup hosts create mgmt $MGMT_VM1_HOST $VM_HD_PASSWORD
../../apicup iface create mgmt $MGMT_VM1_HOST eth0 $MGMT_VM1_IP/$MGMT_VM1_SUBNET_MASK $MGMT_VM1_DEFAULT_GATEWAY
# ../../apicup subsys set mgmt cassandra-backup-protocol=objstore
# ../../apicup subsys set mgmt cassandra-backup-host=s3.us-south.cloud-object-storage.appdomain.cloud/us-south
# ../../apicup subsys set mgmt cassandra-backup-auth-user=$MGMT_BACKUP_USERNAME
# ../../apicup subsys set mgmt cassandra-backup-auth-pass=$MGMT_BACKUP_PASSWORD
# ../../apicup subsys set mgmt cassandra-backup-path=$MGMT_BACKUP_PATH
# ../../apicup subsys set mgmt cassandra-backup-schedule="0 0 * * 0"
echo "================================================================================"
echo "Validating the service configuration"
echo "================================================================================"
../../apicup subsys get mgmt --validate
echo "================================================================================"
