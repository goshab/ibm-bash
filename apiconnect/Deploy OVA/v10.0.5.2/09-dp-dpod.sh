#!/bin/bash
##################################################################################
# This script creates APIC confiuration on a cluster of 3 DataPower gateways.
# 
# Before running this script the following should be configured manually:
# 1) XML Management Interface is enabled on all DataPower gateways.
# 2) REST Management Interface is enabled on all DataPower gateways.
# 3) Same credentials are used for all DataPower gateways.
# 4) DP cert, key, inter ca, root ca located in the same folder with this script.
# 5) Review customer configuration section bellow.
##################################################################################
# Tested on DataPower firmware vesions:
#  10.0.5.2
##################################################################################
# Notes:
#  2018.4.1.9 - the SOMA request for Gateway Peering Manager object is different.
#  x.x.x.x - Another Gateway Peering was added to Gateway Peering Manager.
##################################################################################
# Changes:
#   2022-11-11 Added somaUpdateTimeZone() function to configure UTC timezone.
##################################################################################

##################################################################################
# Create user
#   NEW_USER_ACCESS:
#       privileged
##################################################################################
romaCreateUser() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    ROMA_URL=$3
    NEW_USER_NAME=$4
    NEW_USER_PSW=$5
    NEW_USER_ACCESS=$6
    ROMA_REQ=$(cat <<-EOF
{
    "User": {
        "mAdminState" : "enabled",
        "name" : "$NEW_USER_NAME",
        "Password": "$NEW_USER_PSW",
        "AccessLevel" : "$NEW_USER_ACCESS"
    }
}
EOF
)
    echo "====================================================================================="
    echo "Creating user" $NEW_USER_NAME
    echo "====================================================================================="
    curl -k -u $DP_USERNAME:$DP_PASSWORD -X PUT "${ROMA_URL}/mgmt/config/default/User/${NEW_USER_NAME}" -d "${ROMA_REQ}"
    echo ""
    echo "====================================================================================="
}

##################################################################################
# Main section
##################################################################################
romaCreateUser $DP_USER_NAME_SERVER1 $DP_USER_PASSWORD_SERVER1 $DP_ROMA_URL_SERVER1 "dpod" "newpassword" "privileged"
romaCreateUser $DP_USER_NAME_SERVER2 $DP_USER_PASSWORD_SERVER2 $DP_ROMA_URL_SERVER2 "dpod" "newpassword" "privileged"
romaCreateUser $DP_USER_NAME_SERVER3 $DP_USER_PASSWORD_SERVER3 $DP_ROMA_URL_SERVER3 "dpod" "newpassword" "privileged"



