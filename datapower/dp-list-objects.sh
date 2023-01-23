#!/bin/bash
##################################################################################
# This script lists DataPower objects across all the applicaation domains.
# 
# Prerequisites:
# 1) Make sure the DataPower Rest Management Interface is enabled.
# 2) Review the custom configuration section bellow.
##################################################################################
# Tested on DataPower firmware versions:
#  10.5.0.2
##################################################################################
# Author: Gosha Belenkiy
##################################################################################

##################################################################################
# Custom configuration
# * Filling out all the arguments casuses the script to run siliently. 
# * Leaving the arguments unset will request console input at the runtime.
##################################################################################
dp_host=
dp_roma_port=5554
dp_user=admin
dp_psw=
dp_object=SSLProxyProfile
##################################################################################
# Internal configuration
##################################################################################
if [ -z "$dp_host" ]; then
    read -p 'DataPower hostname or IP: ' dp_host
fi

if [ -z "$dp_roma_port" ]; then
    read -p 'DataPower Rest Management Interface port: ' dp_roma_port
fi

readonly DP_ROMA_URL="https://${dp_host}:${dp_roma_port}"
echo "Rest Management URL: "$DP_ROMA_URL

if [ -z "$dp_user" ]; then
    read -p 'DataPower user name: ' dp_user
else
    echo "DataPower user name: "$dp_user
fi

if [ -z "$dp_psw" ]; then
    read -sp 'DataPower user password: ' dp_psw
    echo
fi

if [ -z "$dp_object" ]; then
    read -p 'DataPower object: ' dp_object
else
    echo "Scanning for DataPower object: "$dp_object
fi

echo
##################################################################################
# Get a list of DataPower objects in a domain
##################################################################################
dp_listObjectsInDomain() {
    DP_USER_NAME=$1
    DP_USER_PASSWORD=$2
    ROMA_URL=$3
    DOMAIN_NAME=$4
    OBJECT_NAME=$5

    response=$(curl -s -k -u $DP_USER_NAME:$DP_USER_PASSWORD -X GET ${ROMA_URL}/mgmt/config/$DOMAIN_NAME/$OBJECT_NAME)
    objects=$(echo $response | jq -r ".${OBJECT_NAME}?.name?")

    if [ "$objects" = "null" ] || [ "$objects" = "" ]; then
        objects=$(echo $response | jq -r ".${OBJECT_NAME}[]?.name?")
    fi

    echo $objects
}

##################################################################################
# Main
##################################################################################
declare -a domains="$(dp_listObjectsInDomain $dp_user $dp_psw $DP_ROMA_URL default Domain)"

if [ -z "$domains" ]; then
    echo "Could not retrieve data from the DataPower"
else
    echo "============ START OF REPORT ============"
    for domain in ${domains[@]}; do
        echo "Domain: $domain"
        declare -a objects="$(dp_listObjectsInDomain $dp_user $dp_psw $DP_ROMA_URL $domain $dp_object)"
        if [ -z "$objects" ]; then
            echo "  $dp_object: not found"
        else
            for object in ${objects[@]}; do
                echo "  $dp_object: $object"
            done
        fi
    done
    echo "============ END OF REPORT ============"
fi