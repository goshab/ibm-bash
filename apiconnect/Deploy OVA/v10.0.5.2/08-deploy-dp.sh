#!/bin/bash
##################################################################################
# This script creates API Connect confiuration on DataPower gateways.
##################################################################################
# Notes:
#  2018.4.1.9 - the SOMA request for Gateway Peering Manager object is different.
#  x.x.x.x - Another Gateway Peering was added to Gateway Peering Manager.
##################################################################################

##################################################################################
# log
##################################################################################
log_success() {
    MSG=$1

    echo -e $GREEN"$MSG"$NC
}
##################################################################################
# log
##################################################################################
log_error() {
    MSG=$1

    echo -e $RED"$MSG"$NC
}
##################################################################################
# log
##################################################################################
log_info() {
    MSG=$1

    echo -e $PURPLE"$MSG"$NC
}
##################################################################################
# log
##################################################################################
log_title() {
    MSG=$1

    echo -e $BLUE"$MSG"$NC
}
##################################################################################
# Calculates number of DP servers
##################################################################################
numOfDpGateways(){
    SEQ=1

    while [ true ]; do
        CUR_DP="$(getIndirectValue DP_MGMT_IP_SERVER $SEQ)"
        if [ -z "$CUR_DP" ]; then
            echo $SEQ
            exit
        fi
        ((SEQ++))
    done
}
##################################################################################
# Get indirect variable value
##################################################################################
getIndirectValue(){
    PREFIX=$1
    SUFFIX=$2

    result="$PREFIX${SUFFIX}"
    result="${!result}"
    echo $result
}
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
    declare -a rmi_response="$(runRoma $DP_USERNAME $DP_PASSWORD "${DP_ROMA_URL_CUSTOM}" "GET" "")"

    if [ "$DEBUG" = "true" ]; then
        echo "RMI response:"
        echo $rmi_response | jq .
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
            log_success "The object $DP_OBJECT_TYPE $DP_OBJECT_NAME is up"
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

    if [ -z "$DP_CRYPTO_ROOTCA_CERT_FILENAME" ]; then
        log_info "Root CA certificate was not provided in the configuration and will not be configured"
    else
        somaUploadFile $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL "default" "sharedcert" $KEYS_DIR $DP_CRYPTO_ROOTCA_CERT_FILENAME
    fi

    if [ -z "$DP_CRYPTO_INTERCA_CERT_FILENAME" ]; then
        log_info "Intermediate CA certificate was not provided in the configuration and will not be configured"
    else
        somaUploadFile $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL "default" "sharedcert" $KEYS_DIR $DP_CRYPTO_INTERCA_CERT_FILENAME
    fi

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

    if [ ! -z "$DP_CRYPTO_ROOTCA_CERT_FILENAME" ]; then
        somaCreateCryptoCert $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_CRYPTO_ROOTCA_CERT_OBJ "sharedcert:///${DP_CRYPTO_ROOTCA_CERT_FILENAME}"
    fi

    if [ ! -z "$DP_CRYPTO_INTERCA_CERT_FILENAME" ]; then
        somaCreateCryptoCert $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_CRYPTO_INTERCA_CERT_OBJ "sharedcert:///${DP_CRYPTO_INTERCA_CERT_FILENAME}"
    fi

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

    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "CryptoCertificate" $DP_CRYPTO_ROOTCA_CERT_OBJ
    validateDpObjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "CryptoCertificate" $DP_CRYPTO_INTERCA_CERT_OBJ
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
    log_error "Syntax error, aborting."
    log_error "  Provide configuration filename as a parameter"
    exit
fi

if [ ! -f ./$1 ]; then
    log_error "Configuration file $1 not found, aborting."
    exit
fi

. $1
. 99-dp-rmi-utils.sh
. 99-dp-xmi-utils.sh

cd $PROJECT_DIR
echo =====================================================================================
echo "Configuring the API Connect Gateway Service on DataPower gateways"
declare -a NUM_OF_DPS="$(numOfDpGateways)"

echo "Number of DataPower gateways: "$NUM_OF_DPS
echo =====================================================================================

for ((CUR_DP_SEQ=0; CUR_DP_SEQ<$NUM_OF_DPS; CUR_DP_SEQ++)); do
    CUR_DP_USERNAME="$(getIndirectValue DP_USER_NAME_SERVER $CUR_DP_SEQ)"
    CUR_DP_PASSWORD="$(getIndirectValue DP_USER_PASSWORD_SERVER $CUR_DP_SEQ)"
    CUR_DP_ROMA_URL="$(getIndirectValue DP_ROMA_URL_SERVER $CUR_DP_SEQ)"

    romaDeleteDomain $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME
done

for ((CUR_DP_SEQ=0; CUR_DP_SEQ<$NUM_OF_DPS; CUR_DP_SEQ++)); do
    deployApicConfigToDataPower $NUM_OF_DPS $CUR_DP_SEQ
done

for ((CUR_DP_SEQ=0; CUR_DP_SEQ<$NUM_OF_DPS; CUR_DP_SEQ++)); do
    verifyApicConfigDeployment $CUR_DP_SEQ
done
