#!/bin/bash

##################################################################################
# Reference:
# https://www.ibm.com/docs/en/datapower-gateway/10.5?topic=interface-samples-that-use-rest-management
##################################################################################

##################################################################################
# runRoma
##################################################################################
runRoma() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_ROMA_URL=$3
    HTTP_METHOD=$4
    DP_ROMA_REQ=$5

    # CLI="curl -s -k -u $DP_USERNAME:$DP_PASSWORD -X $HTTP_METHOD $DP_ROMA_URL"
    # if [ ! -z "$DP_ROMA_REQ" ]; then
    #     CLI=$CLI" -d "\'${DP_ROMA_REQ}\'
    # fi
    # if [ "$DEBUG" = "true" ]; then
    #     echo CLI=$CLI
    # fi

    # response=$(eval $CLI)
    # echo $response

    CLI="curl -w "%{http_code}" -s -k -u $DP_USERNAME:$DP_PASSWORD -X $HTTP_METHOD $DP_ROMA_URL"
    if [ ! -z "$DP_ROMA_REQ" ]; then
        CLI=$CLI" -d "\'${DP_ROMA_REQ}\'
    fi
    response=$(eval $CLI)
    # http_code=$(tail -n1 <<< "$response")
    http_code=${response: -3}
    # http_body=${response:0:-3}
    http_response=${response:0:$((${#response} - 3))}
    # content=$(sed '$ d' <<< "$response")
    # content=$(echo ${response} | head -c-4)
    # echo $http_code
    # echo $content
    echo "{\"http_code\" : $http_code, \"http_response\" : $http_response}"

}
##################################################################################
# Get DataPower object operational state
##################################################################################
romaGetDpOjectOpState() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_ROMA_URL=$3
    DOMAIN_NAME=$4
    OBJECT_TYPE=$5
    OBJECT_NAME=$6

    CLI1='curl -s -k -u '$DP_USERNAME':'$DP_PASSWORD' -X GET '$DP_ROMA_URL'/mgmt/config/'$DOMAIN_NAME'/'$OBJECT_TYPE?state=1
    curl_response=$(eval $CLI1)

    CLI22="echo "\'$curl_response\'' | jq -r '\''.'$OBJECT_TYPE'? | select(.name? == "'$OBJECT_NAME'") | .state.opstate'\'''
    obj_op_state=$(eval $CLI22)
    
    if [ -z "$obj_op_state" ]; then
        CLI32="echo "\'$curl_response\'' | jq -r '\''.'$OBJECT_TYPE'[] | select(.name? == "'$OBJECT_NAME'") | .state.opstate'\'''
        obj_op_state=$(eval $CLI32)
    fi

    echo $obj_op_state
}
##################################################################################
# Delete application domain
##################################################################################
romaDeleteDomain() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_ROMA_URL=$3
    DOMAIN_NAME=$4

    log_title "Deleting application domain $DOMAIN_NAME on $DP_ROMA_URL"
    declare -a RESPONSE="$(runRoma $DP_USERNAME $DP_PASSWORD "${DP_ROMA_URL}/mgmt/config/default/Domain/${DOMAIN_NAME}" "DELETE" "")"
    http_code=$(echo $RESPONSE | jq .http_code)
    if [ "$http_code" = "200" ]; then
        log_success "Success"
    else
        text=$(echo $RESPONSE | jq -r .)
        log_info "$text"
    fi

    echo "====================================================================================="
}
##################################################################################
# Create new DataPower user
##################################################################################
romaCreateUser() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_ROMA_URL=$3
    NEW_USER_NAME=$4
    NEW_USER_PSW=$5
    NEW_USER_ACCESS=$6

    log_title "Creating user $NEW_USER_NAME"
    ROMA_REQ=$(cat <<-EOF
{
    "User": {
        "mAdminState" : "enabled",
        "name" : "$NEW_USER_NAME",
        "Password": "$NEW_USER_PSW",
        "AccessLevel" : "$NEW_USER_ACCESS",
        "SuppressPasswordChange" : "on"
    }
}
EOF
)

    declare -a RESPONSE="$(runRoma $DP_USERNAME $DP_PASSWORD "${DP_ROMA_URL}/mgmt/config/default/User/${NEW_USER_NAME}" "PUT" "${ROMA_REQ}")"
    echo RESPONSE=$RESPONSE
    echo "====================================================================================="
}
##################################################################################
# Get DataPower platform details
##################################################################################
romaGetPlatformDetails() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_ROMA_URL=$3

    declare -a response="$(runRoma $DP_USERNAME $DP_PASSWORD "${DP_ROMA_URL}/mgmt/status/default/VirtualPlatform3" "GET" "")"
    rmi_response=$(echo $response | jq .http_response)
    echo $response | jq .http_code
}
##################################################################################
