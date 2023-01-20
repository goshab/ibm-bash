#!/bin/bash
##################################################################################
# This script lists DataPower object across all domains.
# 
# Before running this script the following should be configured manually:
# 1) DataPower ROMA enabled.
# 2) Review customer configuration section bellow.
##################################################################################
# Tested on:
#  10.5.0.2
##################################################################################

##################################################################################
# Customer configuration
##################################################################################
readonly dp_host=dp.gosha.com
readonly dp_roma_port=5554
readonly dp_user=admin
readonly dp_psw=password
readonly dp_object=SSLProxyProfile
##################################################################################
# Internal configuration
##################################################################################
readonly DP_ROMA_URL="https://${dp_host}:${dp_roma_port}"
##################################################################################
# List DataPower objects in a domain
##################################################################################
dp_listObjectsInDomain() {
    SOMA_USER=$1
    SOMA_PSW=$2
    ROMA_URL=$3
    DOMAIN_NAME=$4
    OBJECT_NAME=$5

    objects=$(curl -s -k -u $SOMA_USER:$SOMA_PSW -X GET ${ROMA_URL}/mgmt/config/$DOMAIN_NAME/$OBJECT_NAME | jq -r ".${OBJECT_NAME}[]?.name?")
    if [ "$objects" = "null" ]; then
        exit
    fi
    echo $objects
}

declare -a domains="$(dp_listObjectsInDomain $dp_user $dp_psw $DP_ROMA_URL default Domain)"

if [[ ${#domains[@]} -gt 0 ]]; then
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
fi