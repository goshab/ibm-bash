#!/bin/bash
##################################################################################
# This script creates API Connect confiuration on DataPower gateways.
##################################################################################
# Notes:
#  2018.4.1.9 - the SOMA request for Gateway Peering Manager object is different.
#  x.x.x.x - Another Gateway Peering was added to Gateway Peering Manager.
##################################################################################

##################################################################################
# Validate DataPower object status
##################################################################################
validateDpObjectStatus() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_ROMA_URL=$3
    DOMAIN_NAME=$4
    OBJECT_TYPE=$5
    OBJECT_NAME=$6

    DP_ROMA_URL_CUSTOM=$DP_ROMA_URL'/mgmt/config/'$DOMAIN_NAME'/'$OBJECT_TYPE?state=1
    declare -a response="$(runRoma $DP_USERNAME $DP_PASSWORD "${DP_ROMA_URL_CUSTOM}" "GET" "")"
    rmi_response=$(echo $response | jq .http_response)

    if [ "$DEBUG" = "true" ]; then
        echo "RMI response:"
        echo $rmi_response | jq .rmi_response
    fi

    CLI21="echo "\'$rmi_response\'' | jq -r '\''.'$OBJECT_TYPE'? | select(.name? == "'$OBJECT_NAME'") | .mAdminState'\'''
    CLI22="echo "\'$rmi_response\'' | jq -r '\''.'$OBJECT_TYPE'? | select(.name? == "'$OBJECT_NAME'") | .state.opstate'\'''
    obj_admin_state=$(eval $CLI21)
    obj_op_state=$(eval $CLI22)
    
    if [ -z "$obj_admin_state" ]; then
        CLI31="echo "\'$rmi_response\'' | jq -r '\''.'$OBJECT_TYPE'[] | select(.name? == "'$OBJECT_NAME'") | .mAdminState'\'''
        CLI32="echo "\'$rmi_response\'' | jq -r '\''.'$OBJECT_TYPE'[] | select(.name? == "'$OBJECT_NAME'") | .state.opstate'\'''
        obj_admin_state=$(eval $CLI31)
        obj_op_state=$(eval $CLI32)
    fi

    if [ ! "$obj_admin_state" = "enabled" ] || [ ! "$obj_op_state" = "up" ]; then
        log_error "$OBJECT_TYPE $OBJECT_NAME: admin_state=$obj_admin_state op_state=$obj_op_state"
        retry $DP_USERNAME $DP_PASSWORD $DP_ROMA_URL $DOMAIN_NAME $OBJECT_TYPE $OBJECT_NAME
    else
        log_success "$OBJECT_TYPE $OBJECT_NAME: admin_state=$obj_admin_state op_state=$obj_op_state"
    fi
}
##################################################################################
# Get DataPower object operational state
##################################################################################
retry() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_ROMA_URL=$3
    DP_APIC_DOMAIN_NAME=$4
    DP_OBJECT_TYPE=$5
    DP_OBJECT_NAME=$6

    for ((i=1; i<=$RETRY_MAX; i++)); do
        declare -a RESULT="$(romaGetDpOjectOpState $DP_USERNAME $DP_PASSWORD $DP_ROMA_URL $DP_APIC_DOMAIN_NAME $DP_OBJECT_TYPE $DP_OBJECT_NAME)"
        if [ "$RESULT" = "up" ]; then
            log_success "Retry "$i"/$RETRY_MAX: The object $DP_OBJECT_TYPE $DP_OBJECT_NAME is up"
            break
        else
            log_info "Retry "$i"/$RETRY_MAX: The object $DP_OBJECT_TYPE $DP_OBJECT_NAME is not up yet, will check again in $RETRY_INTERVAL sec"
            sleep $RETRY_INTERVAL
        fi
    done

    if [ ! "$RESULT" = "up" ]; then
        log_error "The object $DP_OBJECT_TYPE $DP_OBJECT_NAME is not up, aborting"
        exit
    fi
}
##################################################################################
# Deploy APIC config to DP gateway
##################################################################################
deployApicConfigToDataPower() {
    NUM_OF_DPS=$1
    CUR_DP_SEQ=$2

    CUR_DP_USERNAME="$(getIndirectValue DP_USER_NAME_SERVER $CUR_DP_SEQ)"
    CUR_DP_PASSWORD="$(getIndirectValue DP_USER_PASSWORD_SERVER $CUR_DP_SEQ)"
    CUR_DP_SOMA_URL="$(getIndirectValue DP_SOMA_URL_SERVER $CUR_DP_SEQ)"
    CUR_DP_ROMA_URL="$(getIndirectValue DP_ROMA_URL_SERVER $CUR_DP_SEQ)"
    CUR_DP_MGMT_IP="$(getIndirectValue DP_MGMT_IP_SERVER $CUR_DP_SEQ)"
    log_title "Working on $CUR_DP_MGMT_IP"

    somaConfigureDomainStatistics $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL "default"
    somaConfigureThrottler $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL 

    for ((OBJ_SEQ=0; OBJ_SEQ<$NUM_OF_CA_CERTS; OBJ_SEQ++)); do
        CUR_CA_CERT_FILENAME="$(getIndirectValue DP_CRYPTO_CA_CERT_FILENAME $OBJ_SEQ)"
        if [ ! -z "$CUR_CA_CERT_FILENAME" ] && [ ! -f $KEYS_DIR/$CUR_CA_CERT_FILENAME ]; then
            log_info "CA certificate file not found and will not be processed: $KEYS_DIR/$CUR_CA_CERT_FILENAME"
            echo "====================================================================================="
        else
            somaUploadFile $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL "default" "sharedcert" $KEYS_DIR $CUR_CA_CERT_FILENAME
        fi
    done

    somaUploadFile $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL "default" "sharedcert" $KEYS_DIR $DP_CRYPTO_DP_CERT_FILENAME
    somaUploadFile $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL "default" "sharedcert" $KEYS_DIR $DP_CRYPTO_DP_PRIVKEY_FILENAME

    CUR_DP_MNG_HOST_ALIAS="$(getIndirectValue DP_MGMT_HOST_ALIAS_SERVER $CUR_DP_SEQ)"
    CUR_DP_MNG_IP="$(getIndirectValue DP_MGMT_IP_SERVER $CUR_DP_SEQ)"
    somaCreateHostAlias $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $CUR_DP_MNG_HOST_ALIAS $CUR_DP_MNG_IP

    CUR_DP_DATA_HOST_ALIAS="$(getIndirectValue DP_DATA_HOST_ALIAS_SERVER $CUR_DP_SEQ)"
    CUR_DP_DATA_IP="$(getIndirectValue DP_DATA_IP_SERVER $CUR_DP_SEQ)"
    somaCreateHostAlias $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $CUR_DP_DATA_HOST_ALIAS $CUR_DP_DATA_IP

    somaUpdateTimeZone $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_TIMEZONE
    somaCreateDomain $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME
    somaSaveDomainConfiguration $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL "default"

    somaConfigureDomainStatistics $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME
    somaConfigurePasswordAlias $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_PEERING_GROUP_PASSWORD_ALIAS_OBJ $DP_PEERING_GROUP_PASSWORD

    for ((OBJ_SEQ=0; OBJ_SEQ<$NUM_OF_CA_CERTS; OBJ_SEQ++)); do
        CUR_CA_CERT_FILENAME="$(getIndirectValue DP_CRYPTO_CA_CERT_FILENAME $OBJ_SEQ)"
        if [ -f $KEYS_DIR/$CUR_CA_CERT_FILENAME ]; then
            somaCreateCryptoCert $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME $CUR_CA_CERT_FILENAME "sharedcert:///${CUR_CA_CERT_FILENAME}"
        fi
    done

    somaCreateCryptoCert $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_CRYPTO_DP_CERT_OBJ "sharedcert:///${DP_CRYPTO_DP_CERT_FILENAME}"
    somaCreateCryptoKey $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_CRYPTO_DP_KEY_OBJ "sharedcert:///${DP_CRYPTO_DP_PRIVKEY_FILENAME}"
    somaCreateCryptoIdCred $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_CRYPTO_DP_IDCRED_OBJ
    somaCreateSslServer $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_CRYPTO_SSL_SERVER_PROFILE_OBJ
    somaCreateSslClient $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_CRYPTO_SSL_CLIENT_PROFILE_OBJ

    CUR_DP_MGMT_ADDRESS="$(getIndirectValue DP_MGMT_HOST_ALIAS_SERVER $CUR_DP_SEQ)"
    CUR_DP_DATA_ADDRESS="$(getIndirectValue DP_DATA_HOST_ALIAS_SERVER $CUR_DP_SEQ)"
    CUR_DP_PRIORITY="$(getIndirectValue DP_GWD_PEERING_PRIORITY_SERVER $CUR_DP_SEQ)"
    DP2_SEQ=$((($CUR_DP_SEQ+1)%3))
    DP2_MGMT_HOSTNAME="$(getIndirectValue DP_MGMT_HOSTNAME_SERVER $DP2_SEQ)"
    DP3_SEQ=$((($CUR_DP_SEQ+2)%3))
    DP3_MGMT_HOSTNAME="$(getIndirectValue DP_MGMT_HOSTNAME_SERVER $DP3_SEQ)"

    somaCreateGatewayPeering $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME $DP2_MGMT_HOSTNAME $DP3_MGMT_HOSTNAME $DP_PEERING_MGR_API_PROBE      16383 26383 $CUR_DP_PRIORITY "memory" $CUR_DP_MGMT_ADDRESS
    somaCreateGatewayPeering $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME $DP2_MGMT_HOSTNAME $DP3_MGMT_HOSTNAME $DP_PEERING_MGR_TOKENS         16385 26385 $CUR_DP_PRIORITY "local"  $CUR_DP_MGMT_ADDRESS
    somaCreateGatewayPeering $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME $DP2_MGMT_HOSTNAME $DP3_MGMT_HOSTNAME $DP_PEERING_MGR_APICGW         16380 26380 $CUR_DP_PRIORITY "memory" $CUR_DP_MGMT_ADDRESS
    somaCreateGatewayPeering $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME $DP2_MGMT_HOSTNAME $DP3_MGMT_HOSTNAME $DP_PEERING_MGR_API_RATE_LIMIT 16381 26381 $CUR_DP_PRIORITY "memory" $CUR_DP_MGMT_ADDRESS
    somaCreateGatewayPeering $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME $DP2_MGMT_HOSTNAME $DP3_MGMT_HOSTNAME $DP_PEERING_MGR_SUBS           16382 26382 $CUR_DP_PRIORITY "memory" $CUR_DP_MGMT_ADDRESS
    somaCreateGatewayPeering $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME $DP2_MGMT_HOSTNAME $DP3_MGMT_HOSTNAME $DP_PEERING_MGR_GWS_RATE_LIMIT 16384 26384 $CUR_DP_PRIORITY "memory" $CUR_DP_MGMT_ADDRESS
    somaCreateGatewayPeeringManager $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_PEERING_MGR_APICGW $DP_PEERING_MGR_API_RATE_LIMIT $DP_PEERING_MGR_SUBS $DP_PEERING_MGR_API_PROBE $DP_PEERING_MGR_GWS_RATE_LIMIT
    
    somaCreateConfigSequence $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME
    somaCreateApiConnectGatewayService $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME $CUR_DP_MGMT_ADDRESS $CUR_DP_DATA_ADDRESS

    somaCreateApicSecurityTokenManager $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME

    retry $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "GatewayPeering" $DP_PEERING_MGR_API_PROBE
    somaConfigureApiProbe $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL 1000 60 $DP_PEERING_MGR_API_PROBE $CUR_DP_SEQ

    somaSaveDomainConfiguration $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME
}
##################################################################################
# Verify APIC config deployment
##################################################################################
verifyApicConfigDeployment() {
    CUR_DP_SEQ=$1

    log_title "Verifying APIC config on DP gateway $(getIndirectValue DP_MGMT_IP_SERVER $CUR_DP_SEQ)"

    CUR_DP_USERNAME="$(getIndirectValue DP_USER_NAME_SERVER $CUR_DP_SEQ)"
    CUR_DP_PASSWORD="$(getIndirectValue DP_USER_PASSWORD_SERVER $CUR_DP_SEQ)"
    CUR_DP_ROMA_URL="$(getIndirectValue DP_ROMA_URL_SERVER $CUR_DP_SEQ)"

    CUR_DP_MNG_HOST_ALIAS="$(getIndirectValue DP_MGMT_HOST_ALIAS_SERVER $CUR_DP_SEQ)"
    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL "default" "HostAlias" $CUR_DP_MNG_HOST_ALIAS

    CUR_DP_DATA_HOST_ALIAS="$(getIndirectValue DP_DATA_HOST_ALIAS_SERVER $CUR_DP_SEQ)"
    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL "default" "HostAlias" $CUR_DP_DATA_HOST_ALIAS

    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL "default" "Domain" $DP_APIC_DOMAIN_NAME

    for ((OBJ_SEQ=0; OBJ_SEQ<$NUM_OF_CA_CERTS; OBJ_SEQ++)); do
        CUR_CA_CERT_FILENAME="$(getIndirectValue DP_CRYPTO_CA_CERT_FILENAME $OBJ_SEQ)"
        if [ -f $KEYS_DIR/$CUR_CA_CERT_FILENAME ]; then
            validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "CryptoCertificate" $CUR_CA_CERT_FILENAME
        fi
    done

    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "CryptoCertificate" $DP_CRYPTO_DP_CERT_OBJ
    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "CryptoKey" $DP_CRYPTO_DP_KEY_OBJ
    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "CryptoIdentCred" $DP_CRYPTO_DP_IDCRED_OBJ
    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "SSLServerProfile" $DP_CRYPTO_SSL_SERVER_PROFILE_OBJ
    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "SSLClientProfile" $DP_CRYPTO_SSL_CLIENT_PROFILE_OBJ

    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "GatewayPeering" $DP_PEERING_MGR_APICGW
    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "GatewayPeering" $DP_PEERING_MGR_API_RATE_LIMIT
    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "GatewayPeering" $DP_PEERING_MGR_SUBS
    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "GatewayPeering" $DP_PEERING_MGR_API_PROBE
    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "GatewayPeering" $DP_PEERING_MGR_GWS_RATE_LIMIT
    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "GatewayPeeringManager" "default"
    
    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "ConfigSequence" $DP_CONFIG_SEQUENCE_OBJ
    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "APIConnectGatewayService" "default"

    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "GatewayPeering" $DP_PEERING_MGR_TOKENS
    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "APISecurityTokenManager" "default"

    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "APIDebugProbe" "default"
    echo "====================================================================================="
}
##################################################################################
# Main section
##################################################################################
if [ -z "$1" ]; then
    echo "Syntax error, aborting."
    echo "  Provide configuration filename as a parameter"
    exit
fi

if [ ! -f ./$1 ]; then
    echo "Configuration file $1 not found, aborting."
    exit
fi

. $1
. ../../../utils/utils.sh
# . ../../../utils/dp-rmi-utils.sh
# . ../../../utils/dp-xmi-utils.sh

cd $PROJECT_DIR
echo =====================================================================================
echo "Configuring the API Connect Gateway Service on DataPower gateways"

if [ ! -f $KEYS_DIR/$DP_CRYPTO_DP_CERT_FILENAME ]; then
    log_error "Certificate file not found, aborting: $KEYS_DIR/$DP_CRYPTO_DP_CERT_FILENAME"
    exit
    echo "====================================================================================="
fi
if [ ! -f $KEYS_DIR/$DP_CRYPTO_DP_PRIVKEY_FILENAME ]; then
    log_error "Private key file not found, aborting: $KEYS_DIR/$DP_CRYPTO_DP_PRIVKEY_FILENAME"
    exit
    echo "====================================================================================="
fi

declare -a NUM_OF_DPS="$(numOfObjects "DP_MGMT_IP_SERVER")"
declare -a NUM_OF_CA_CERTS="$(numOfObjects "DP_CRYPTO_CA_CERT_FILENAME")"

echo "Number of DataPower gateways: "$NUM_OF_DPS
echo "Number of CA certs: "$NUM_OF_CA_CERTS

for ((CUR_DP_SEQ=0; CUR_DP_SEQ<$NUM_OF_DPS; CUR_DP_SEQ++)); do
    CUR_HOST="$(getIndirectValue DP_MGMT_HOSTNAME_SERVER $CUR_DP_SEQ)"
    CUR_SOMA_PORT="$(getIndirectValue DP_SOMA_PORT_SERVER $CUR_DP_SEQ)"
    CUR_ROMA_PORT="$(getIndirectValue DP_ROMA_PORT_SERVER $CUR_DP_SEQ)"
    declare DP_SOMA_URL_SERVER$CUR_DP_SEQ="https://${CUR_HOST}:${CUR_SOMA_PORT}${DP_SOMA_URI}"
    declare DP_ROMA_URL_SERVER$CUR_DP_SEQ="https://${CUR_HOST}:${CUR_ROMA_PORT}"
done

echo =====================================================================================
for ((CUR_DP_SEQ=0; CUR_DP_SEQ<$NUM_OF_DPS; CUR_DP_SEQ++)); do
    CUR_DP_USERNAME="$(getIndirectValue DP_USER_NAME_SERVER $CUR_DP_SEQ)"
    CUR_DP_PASSWORD="$(getIndirectValue DP_USER_PASSWORD_SERVER $CUR_DP_SEQ)"
    CUR_DP_ROMA_URL="$(getIndirectValue DP_ROMA_URL_SERVER $CUR_DP_SEQ)"
    CUR_DP_SOMA_URL="$(getIndirectValue DP_SOMA_URL_SERVER $CUR_DP_SEQ)"

    romaDeleteDomain $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME
    somaSaveDomainConfiguration $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL "default"
done

for ((CUR_DP_SEQ=0; CUR_DP_SEQ<$NUM_OF_DPS; CUR_DP_SEQ++)); do
    deployApicConfigToDataPower $NUM_OF_DPS $CUR_DP_SEQ
done

for ((CUR_DP_SEQ=0; CUR_DP_SEQ<$NUM_OF_DPS; CUR_DP_SEQ++)); do
    verifyApicConfigDeployment $CUR_DP_SEQ
done
