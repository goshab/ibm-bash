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
echo "Configuring the "$A7S_APIC_SUBSYSTEM_NAME" service"
echo "================================================================================"
../../apicup subsys create analyt $A7S_APIC_SUBSYSTEM_NAME
../../apicup subsys set analyt deployment-profile $A7S_APIC_DEPLOYMENT_PROFILE
../../apicup subsys set analyt license-use $APIC_LICENSE

../../apicup subsys set analyt search-domain $A7S_SEARCH_DOMAIN
../../apicup subsys set analyt dns-servers=$A7S_DNS_SERVERS

../../apicup subsys set analyt analytics-ingestion $A7S_ENDPOINT_AI
# ../../apicup subsys set analyt analytics-client input_analytics_client_url

../../apicup subsys set analyt ssh-keyfiles $VM_APICADM_SSH_KEY_FILENAME.pub
../../apicup subsys set analyt default-password $VM_APICADM_PASSWORD_HASHED

../../apicup hosts create analyt $A7S_VM1_HOST $VM_HD_PASSWORD
../../apicup iface create analyt $A7S_VM1_HOST eth0 $A7S_VM1_IP/$A7S_VM1_SUBNET_MASK $A7S_VM1_DEFAULT_GATEWAY
echo "================================================================================"
echo "Validating the service configuration"
echo "================================================================================"
../../apicup subsys get analyt --validate
echo "================================================================================"
