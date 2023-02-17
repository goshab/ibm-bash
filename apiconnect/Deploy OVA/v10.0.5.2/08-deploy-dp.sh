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
# runSoma
##################################################################################
runSoma() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DP_SOMA_REQ=$4

    # curl -k -X POST -u $DP_USERNAME:$DP_PASSWORD $DP_SOMA_URL -d "${DP_SOMA_REQ}"
    response=$(curl -s -k -X POST -u $DP_USERNAME:$DP_PASSWORD $DP_SOMA_URL -d "${DP_SOMA_REQ}")
    analysis=$(echo $response | grep -o 'OK')
    if [ "$analysis" = "OK" ]; then
        echo -e "Result: "$GREEN"Success"$NC
        if [ "$DEBUG" = "true" ]; then
            echo Response
            echo $response
        fi
   else
        echo -e $RED"Error, DataPower SOMA response:"$NC
        echo -e ${response}$NC
        exit
    fi
}
##################################################################################
# Upload file
##################################################################################
somaUploadFile() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4
    DP_FOLDER=$5
    LOCAL_FOLDER=$6
    FILE_NAME=$7

    FILE_CONTENT_BASE64ENCODED=$(base64 $LOCAL_FOLDER/$FILE_NAME)
    DEST_FILE_PATH=$DP_FOLDER:///$FILE_NAME
    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-file name="$DEST_FILE_PATH">$FILE_CONTENT_BASE64ENCODED</dp:set-file>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Uploading $LOCAL_FOLDER/$FILE_NAME file to" $DEST_FILE_PATH
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Create Crypto ID Cred
##################################################################################
somaCreateCryptoIdCred() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4
    OBJ_NAME=$5


    if [ ! -z "$DP_CRYPTO_ROOTCA_CERT_FILENAME" ]; then
        ROOT_CA="<CA>"$DP_CRYPTO_ROOTCA_CERT_OBJ"</CA>"
    fi

    if [ ! -z "$DP_CRYPTO_INTERCA_CERT_FILENAME" ]; then
        INTER_CA="<CA>"$DP_CRYPTO_INTERCA_CERT_OBJ"</CA>"
    fi

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <CryptoIdentCred name="$OBJ_NAME">
                    <mAdminState>enabled</mAdminState>
                    <Key>$DP_CRYPTO_DP_KEY_OBJ</Key>
                    <Certificate>$DP_CRYPTO_DP_CERT_OBJ</Certificate>
                    $ROOT_CA
                    $INTER_CA
                </CryptoIdentCred>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Creating crypto id credentials" $OBJ_NAME
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Set UTC time zone
##################################################################################
somaUpdateTimeZone() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DP_TIMEZONE=$4

    SOMA_REQ=$(cat <<-EOF
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ma="http://www.datapower.com/schemas/management">
   <SOAP-ENV:Body>
        <ma:request domain="default">
            <ma:modify-config>
                <TimeSettings>
                    <LocalTimeZone>$DP_TIMEZONE</LocalTimeZone>
                </TimeSettings>
            </ma:modify-config>
        </ma:request>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
EOF
)
    echo "====================================================================================="
    echo "Setting time zone to "$DP_TIMEZONE
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Create API Security Token Manager
##################################################################################
somaCreateApicSecurityTokenManager() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <APISecurityTokenManager name="default">
                    <mAdminState>enabled</mAdminState>
                    <GatewayPeering>$DP_PEERING_MGR_TOKENS</GatewayPeering>
                </APISecurityTokenManager>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Creating API Security Token Manager"
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Create Crypto Cert
##################################################################################
somaCreateCryptoCert() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4
    OBJ_NAME=$5
    FILE_NAME=$6

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <CryptoCertificate name="$OBJ_NAME">
                    <mAdminState>enabled</mAdminState>
                    <Filename>$FILE_NAME</Filename>
                    <Password></Password>
                    <PasswordAlias>off</PasswordAlias>
                    <Alias></Alias>
                    <IgnoreExpiration>off</IgnoreExpiration>
                </CryptoCertificate>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Creating crypto cert" $OBJ_NAME
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Create Crypto Key
##################################################################################
somaCreateCryptoKey() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4
    OBJ_NAME=$5
    FILE_NAME=$6

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <CryptoKey name="$OBJ_NAME">
                    <mAdminState>enabled</mAdminState>
                    <Filename>$FILE_NAME</Filename>
                    <Password></Password>
                    <PasswordAlias>off</PasswordAlias>
                    <Alias></Alias>
                </CryptoKey>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Creating crypto key" $OBJ_NAME
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Save domain configuration
##################################################################################
somaSaveDomainConfiguration() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:do-action>
                <SaveConfig></SaveConfig>
            </dp:do-action>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Save domain configuration" $DOMAIN_NAME
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Create new DataPower application domain
##################################################################################
somaCreateDomain() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="default">
            <dp:set-config>
                <Domain name="$DOMAIN_NAME">
                    <mAdminState>enabled</mAdminState>
                    <UserSummary>API Connect</UserSummary>
                    <NeighborDomain>default</NeighborDomain>
                </Domain>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Creating domain" $DOMAIN_NAME
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Create Host Aliases
##################################################################################
somaCreateHostAlias() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    ALIAS_NAME=$4
    IPADDRESS=$5

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="default">
            <dp:set-config>
                <HostAlias name="$ALIAS_NAME">
                    <mAdminState>enabled</mAdminState>
                    <IPAddress>$IPADDRESS</IPAddress>
                </HostAlias>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)
    echo "====================================================================================="
    echo "Creating Host Aliases" $ALIAS_NAME "as" $IPADDRESS
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Configure NTP Service
##################################################################################
somaConfigureNtpService() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    NTP_IP=$4

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="default">
            <dp:set-config>
                <NTPService name="$ALIAS_NAME">
                    <mAdminState>enabled</mAdminState>
                    <RefreshInterval>900</RefreshInterval>
                    <RemoteServer>$NTP_IP</RemoteServer>
                </NTPService>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)
    echo "====================================================================================="
    echo "Configuring NTP Service"
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Configure API Probe
##################################################################################
somaConfigureApiProbe() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    MAX_RECORDS=$4
    EXPIRATION=$5
    GATEWAY_PEERING=$6
    DP_SEQ=$7

    echo "====================================================================================="
    echo "Configuring API Probe"

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <APIDebugProbe name="default">
                    <mAdminState>enabled</mAdminState>
                    <MaxRecords>$MAX_RECORDS</MaxRecords>
                    <Expiration>$EXPIRATION</Expiration>
                    <GatewayPeering>$GATEWAY_PEERING</GatewayPeering>
                </APIDebugProbe>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    retry $DP_SEQ $DP_APIC_DOMAIN_NAME "GatewayPeering" $GATEWAY_PEERING

    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Configure Password Alias
##################################################################################
somaConfigurePasswordAlias() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4
    OBJ_NAME=$5
    PASSWORD=$6

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <PasswordAlias name="$OBJ_NAME">
                    <mAdminState>enabled</mAdminState>
                    <Password>$PASSWORD</Password>
                </PasswordAlias>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)
    echo "====================================================================================="
    echo "Configuring Password Map Alias "$OBJ_NAME
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Create SSL/TLS Server
##################################################################################
somaCreateSslServer() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4
    SSLSERVERPROFILE=$5

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <SSLServerProfile name="$SSLSERVERPROFILE">
                    <mAdminState>enabled</mAdminState>
                    <UserSummary>Gwd server profile</UserSummary>
                    <Protocols>
                        <SSLv3>off</SSLv3>
                        <TLSv1d0>off</TLSv1d0>
                        <TLSv1d1>off</TLSv1d1>
                        <TLSv1d2>on</TLSv1d2>
                    </Protocols>
                    <Ciphers>ECDHE_ECDSA_WITH_AES_256_GCM_SHA384</Ciphers>
                    <Ciphers>ECDHE_RSA_WITH_AES_256_GCM_SHA384</Ciphers>
                    <Ciphers>ECDHE_ECDSA_WITH_AES_256_CBC_SHA384</Ciphers>
                    <Ciphers>ECDHE_RSA_WITH_AES_256_CBC_SHA384</Ciphers>
                    <Ciphers>ECDHE_ECDSA_WITH_AES_256_CBC_SHA</Ciphers>
                    <Ciphers>ECDHE_RSA_WITH_AES_256_CBC_SHA</Ciphers>
                    <Ciphers>DHE_DSS_WITH_AES_256_GCM_SHA384</Ciphers>
                    <Ciphers>DHE_RSA_WITH_AES_256_GCM_SHA384</Ciphers>
                    <Ciphers>DHE_RSA_WITH_AES_256_CBC_SHA256</Ciphers>
                    <Ciphers>DHE_DSS_WITH_AES_256_CBC_SHA256</Ciphers>
                    <Ciphers>DHE_RSA_WITH_AES_256_CBC_SHA</Ciphers>
                    <Ciphers>DHE_DSS_WITH_AES_256_CBC_SHA</Ciphers>
                    <Ciphers>RSA_WITH_AES_256_GCM_SHA384</Ciphers>
                    <Ciphers>RSA_WITH_AES_256_CBC_SHA256</Ciphers>
                    <Ciphers>RSA_WITH_AES_256_CBC_SHA</Ciphers>
                    <Ciphers>ECDHE_ECDSA_WITH_AES_128_GCM_SHA256</Ciphers>
                    <Ciphers>ECDHE_RSA_WITH_AES_128_GCM_SHA256</Ciphers>
                    <Ciphers>ECDHE_ECDSA_WITH_AES_128_CBC_SHA256</Ciphers>
                    <Ciphers>ECDHE_RSA_WITH_AES_128_CBC_SHA256</Ciphers>
                    <Ciphers>ECDHE_ECDSA_WITH_AES_128_CBC_SHA</Ciphers>
                    <Ciphers>ECDHE_RSA_WITH_AES_128_CBC_SHA</Ciphers>
                    <Ciphers>DHE_DSS_WITH_AES_128_GCM_SHA256</Ciphers>
                    <Ciphers>DHE_RSA_WITH_AES_128_GCM_SHA256</Ciphers>
                    <Ciphers>DHE_RSA_WITH_AES_128_CBC_SHA256</Ciphers>
                    <Ciphers>DHE_DSS_WITH_AES_128_CBC_SHA256</Ciphers>
                    <Ciphers>DHE_RSA_WITH_AES_128_CBC_SHA</Ciphers>
                    <Ciphers>DHE_DSS_WITH_AES_128_CBC_SHA</Ciphers>
                    <Ciphers>RSA_WITH_AES_128_GCM_SHA256</Ciphers>
                    <Ciphers>RSA_WITH_AES_128_CBC_SHA256</Ciphers>
                    <Ciphers>RSA_WITH_AES_128_CBC_SHA</Ciphers>
                    <Ciphers>ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA</Ciphers>
                    <Ciphers>ECDHE_RSA_WITH_3DES_EDE_CBC_SHA</Ciphers>
                    <Ciphers>DHE_RSA_WITH_3DES_EDE_CBC_SHA</Ciphers>
                    <Ciphers>DHE_DSS_WITH_3DES_EDE_CBC_SHA</Ciphers>
                    <Ciphers>RSA_WITH_3DES_EDE_CBC_SHA</Ciphers>
                    <Idcred>$DP_CRYPTO_DP_IDCRED_OBJ</Idcred>
                    <RequestClientAuth>off</RequestClientAuth>
                    <RequireClientAuth>off</RequireClientAuth>
                    <ValidateClientCert>off</ValidateClientCert>
                    <SendClientAuthCAList>on</SendClientAuthCAList>
                    <Valcred></Valcred>
                    <Caching>on</Caching>
                    <CacheTimeout>300</CacheTimeout>
                    <CacheSize>20</CacheSize>
                    <SSLOptions>
                        <max-duration>off</max-duration>
                        <max-renegotiation>off</max-renegotiation>
                    </SSLOptions>
                    <MaxSSLDuration>60</MaxSSLDuration>
                    <NumberOfRenegotiationAllowed>0</NumberOfRenegotiationAllowed>
                    <ProhibitResumeOnReneg>off</ProhibitResumeOnReneg>
                    <Compression>off</Compression>
                    <AllowLegacyRenegotiation>off</AllowLegacyRenegotiation>
                    <PreferServerCiphers>on</PreferServerCiphers>
                    <EllipticCurves>secp521r1</EllipticCurves>
                    <EllipticCurves>secp384r1</EllipticCurves>
                    <EllipticCurves>secp256k1</EllipticCurves>
                    <EllipticCurves>secp256r1</EllipticCurves>
                </SSLServerProfile>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Creating SSL Server Profile" $SSLSERVERPROFILE
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Create SSL/TLS Server
##################################################################################
somaCreateSslClient() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4
    SSLCLIENTPROFILE=$5

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <SSLClientProfile name="$SSLCLIENTPROFILE">
                    <mAdminState>enabled</mAdminState>
                    <UserSummary>gwd client profile</UserSummary>
                    <Protocols>
                        <SSLv3>off</SSLv3>
                        <TLSv1d0>off</TLSv1d0>
                        <TLSv1d1>off</TLSv1d1>
                        <TLSv1d2>on</TLSv1d2>
                    </Protocols>
                    <Ciphers>ECDHE_ECDSA_WITH_AES_256_GCM_SHA384</Ciphers>
                    <Ciphers>ECDHE_RSA_WITH_AES_256_GCM_SHA384</Ciphers>
                    <Ciphers>ECDHE_ECDSA_WITH_AES_256_CBC_SHA384</Ciphers>
                    <Ciphers>ECDHE_RSA_WITH_AES_256_CBC_SHA384</Ciphers>
                    <Ciphers>ECDHE_ECDSA_WITH_AES_256_CBC_SHA</Ciphers>
                    <Ciphers>ECDHE_RSA_WITH_AES_256_CBC_SHA</Ciphers>
                    <Ciphers>DHE_DSS_WITH_AES_256_GCM_SHA384</Ciphers>
                    <Ciphers>DHE_RSA_WITH_AES_256_GCM_SHA384</Ciphers>
                    <Ciphers>DHE_RSA_WITH_AES_256_CBC_SHA256</Ciphers>
                    <Ciphers>DHE_DSS_WITH_AES_256_CBC_SHA256</Ciphers>
                    <Ciphers>DHE_RSA_WITH_AES_256_CBC_SHA</Ciphers>
                    <Ciphers>DHE_DSS_WITH_AES_256_CBC_SHA</Ciphers>
                    <Ciphers>RSA_WITH_AES_256_GCM_SHA384</Ciphers>
                    <Ciphers>RSA_WITH_AES_256_CBC_SHA256</Ciphers>
                    <Ciphers>RSA_WITH_AES_256_CBC_SHA</Ciphers>
                    <Ciphers>ECDHE_ECDSA_WITH_AES_128_GCM_SHA256</Ciphers>
                    <Ciphers>ECDHE_RSA_WITH_AES_128_GCM_SHA256</Ciphers>
                    <Ciphers>ECDHE_ECDSA_WITH_AES_128_CBC_SHA256</Ciphers>
                    <Ciphers>ECDHE_RSA_WITH_AES_128_CBC_SHA256</Ciphers>
                    <Ciphers>ECDHE_ECDSA_WITH_AES_128_CBC_SHA</Ciphers>
                    <Ciphers>ECDHE_RSA_WITH_AES_128_CBC_SHA</Ciphers>
                    <Ciphers>DHE_DSS_WITH_AES_128_GCM_SHA256</Ciphers>
                    <Ciphers>DHE_RSA_WITH_AES_128_GCM_SHA256</Ciphers>
                    <Ciphers>DHE_RSA_WITH_AES_128_CBC_SHA256</Ciphers>
                    <Ciphers>DHE_DSS_WITH_AES_128_CBC_SHA256</Ciphers>
                    <Ciphers>DHE_RSA_WITH_AES_128_CBC_SHA</Ciphers>
                    <Ciphers>DHE_DSS_WITH_AES_128_CBC_SHA</Ciphers>
                    <Ciphers>RSA_WITH_AES_128_GCM_SHA256</Ciphers>
                    <Ciphers>RSA_WITH_AES_128_CBC_SHA256</Ciphers>
                    <Ciphers>RSA_WITH_AES_128_CBC_SHA</Ciphers>
                    <Ciphers>ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA</Ciphers>
                    <Ciphers>ECDHE_RSA_WITH_3DES_EDE_CBC_SHA</Ciphers>
                    <Ciphers>DHE_RSA_WITH_3DES_EDE_CBC_SHA</Ciphers>
                    <Ciphers>DHE_DSS_WITH_3DES_EDE_CBC_SHA</Ciphers>
                    <Ciphers>RSA_WITH_3DES_EDE_CBC_SHA</Ciphers>
                    <Idcred>$DP_CRYPTO_DP_IDCRED_OBJ</Idcred>
                    <ValidateServerCert>off</ValidateServerCert>
                    <Valcred></Valcred>
                    <Caching>on</Caching>
                    <CacheTimeout>300</CacheTimeout>
                    <CacheSize>100</CacheSize>
                    <SSLClientFeatures>
                        <use-sni>on</use-sni>
                        <permit-insecure-servers>off</permit-insecure-servers>
                        <compression>off</compression>
                    </SSLClientFeatures>
                    <EllipticCurves>secp521r1</EllipticCurves>
                    <EllipticCurves>secp384r1</EllipticCurves>
                    <EllipticCurves>secp256k1</EllipticCurves>
                    <EllipticCurves>secp256r1</EllipticCurves>
                    <UseCustomSNIHostname>no</UseCustomSNIHostname>
                    <CustomSNIHostname></CustomSNIHostname>
                    <ValidateHostname>off</ValidateHostname>
                    <HostnameValidationFlags>
                        <X509_CHECK_FLAG_ALWAYS_CHECK_SUBJECT>off</X509_CHECK_FLAG_ALWAYS_CHECK_SUBJECT>
                        <X509_CHECK_FLAG_NO_WILDCARDS>off</X509_CHECK_FLAG_NO_WILDCARDS>
                        <X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS>off</X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS>
                        <X509_CHECK_FLAG_MULTI_LABEL_WILDCARDS>off</X509_CHECK_FLAG_MULTI_LABEL_WILDCARDS>
                        <X509_CHECK_FLAG_SINGLE_LABEL_SUBDOMAINS>off</X509_CHECK_FLAG_SINGLE_LABEL_SUBDOMAINS>
                    </HostnameValidationFlags>
                    <HostnameValidationFailOnError>off</HostnameValidationFailOnError>
                </SSLClientProfile>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Creating SSL Client Profile" $SSLCLIENTPROFILE
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Create Gateway Peering
##################################################################################
somaCreateGatewayPeering() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4
    PEER2=$5
    PEER3=$6
    PEERING_NAME=$7
    LOCAL_PORT=$8
    MONITOR_PORT=$9
    PRIORITY=${10}
    LOCATION=${11}
    DP_MGMT_ADDRESS=${12}

    echo "====================================================================================="
    echo "Creating Gateway Peering" $PEERING_NAME

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <GatewayPeering name="$PEERING_NAME">
                    <mAdminState>enabled</mAdminState>
                    <LocalAddress>$DP_MGMT_ADDRESS</LocalAddress>
                    <LocalPort>$LOCAL_PORT</LocalPort>
                    <MonitorPort>$MONITOR_PORT</MonitorPort>
                    <EnablePeerGroup>on</EnablePeerGroup>
                    <Peers>$PEER2</Peers>
                    <Peers>$PEER3</Peers>
                    <Priority>$PRIORITY</Priority>
                    <EnableSSL>on</EnableSSL>
                    <Idcred>$DP_CRYPTO_DP_IDCRED_OBJ</Idcred>
                    <Valcred></Valcred>
                    <PersistenceLocation>$LOCATION</PersistenceLocation>
                    <LocalDirectory>local:///</LocalDirectory>
                    <PasswordAlias>$DP_PEERING_GROUP_PASSWORD_ALIAS_OBJ</PasswordAlias>
                </GatewayPeering>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Create Gateway Peering Manager
##################################################################################
somaCreateGatewayPeeringManager() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4
    PEERING_MGR_APICGW=$5
    PEERING_MGR_API_RATE_LIMIT=$6
    PEERING_MGR_SUBS=$7
    PEERING_MGR_API_PROBE=$8
    PEERING_MGR_GWS_RATE_LIMIT=$9

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <GatewayPeeringManager name="default">
                    <mAdminState>enabled</mAdminState>
                    <APIConnectGatewayService>$PEERING_MGR_APICGW</APIConnectGatewayService>
                    <RateLimit>$PEERING_MGR_API_RATE_LIMIT</RateLimit>
                    <Subscription>$PEERING_MGR_SUBS</Subscription>
                    <APIProbe>$PEERING_MGR_API_PROBE</APIProbe>
                    <RatelimitModule>$PEERING_MGR_GWS_RATE_LIMIT</RatelimitModule>
                </GatewayPeeringManager>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Creating Gateway Peering Manager"
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Create Config Sequence
##################################################################################
somaCreateConfigSequence() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4
    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <ConfigSequence name="$DP_CONFIG_SEQUENCE_OBJ">
                    <mAdminState>enabled</mAdminState>
                    <Locations>
                        <Directory>local:///</Directory>
                        <AccessProfileName/>
                    </Locations>
                    <MatchPattern>(.*)\.cfg$</MatchPattern>
                    <ResultNamePattern>$1.log</ResultNamePattern>
                    <StatusNamePattern>$1.status</StatusNamePattern>
                    <Watch>on</Watch>
                    <UseOutputLocation>off</UseOutputLocation>
                    <OutputLocation>logtemp:///</OutputLocation>
                    <DeleteUnused>on</DeleteUnused>
                    <RunSequenceInterval>3000</RunSequenceInterval>
                </ConfigSequence>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Creating Config Sequence"
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Create API Connect Gateway Service
##################################################################################
somaCreateApiConnectGatewayService() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4
    DP_MGMT_ADDRESS=$5
    DP_DATA_ADDRESS=$6

                    # <GatewayPeering>$DP_PEERING_MGR_APICGW</GatewayPeering>
                    # <GatewayPeering>none</GatewayPeering>
    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <APIConnectGatewayService name="default">
                    <mAdminState>enabled</mAdminState>
                    <LocalAddress>$DP_MGMT_ADDRESS</LocalAddress>
                    <LocalPort>$DP_GWD_ENDPOINT_PORT</LocalPort>
                    <SSLClient>$DP_CRYPTO_SSL_CLIENT_PROFILE_OBJ</SSLClient>
                    <SSLServer>$DP_CRYPTO_SSL_SERVER_PROFILE_OBJ</SSLServer>
                    <APIGatewayAddress>$DP_DATA_ADDRESS</APIGatewayAddress>
                    <APIGatewayPort>$DP_GW_ENDPOINT_PORT</APIGatewayPort>
                    <GatewayPeeringManager>default</GatewayPeeringManager>
                    <V5CompatibilityMode>off</V5CompatibilityMode>
                    <UserDefinedPolicies></UserDefinedPolicies>
                    <V5CSlmMode>autounicast</V5CSlmMode>
                    <IPMulticast></IPMulticast>
                    <IPUnicast></IPUnicast>
                </APIConnectGatewayService>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Creating API Connect Gateway Service"
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
}
##################################################################################
# Check DataPower object status
##################################################################################
romaCheckDpOjectStatus() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_ROMA_URL=$3
    DOMAIN_NAME=$4
    OBJECT_TYPE=$5
    OBJECT_NAME=$6

    CLI1='curl -s -k -u '$DP_USERNAME':'$DP_PASSWORD' -X GET '$DP_ROMA_URL'/mgmt/config/'$DOMAIN_NAME'/'$OBJECT_TYPE?state=1
    if [ "$DEBUG" = "true" ]; then
        echo "curl CLI:"
        echo $CLI1
    fi
    curl_response=$(eval $CLI1)
    if [ "$DEBUG" = "true" ]; then
        echo "curl response:"
        echo $curl_response | jq .
    fi

    CLI21="echo "\'$curl_response\'' | jq -r '\''.'$OBJECT_TYPE'? | select(.name? == "'$OBJECT_NAME'") | .mAdminState'\'''
    CLI22="echo "\'$curl_response\'' | jq -r '\''.'$OBJECT_TYPE'? | select(.name? == "'$OBJECT_NAME'") | .state.opstate'\'''
    obj_admin_state=$(eval $CLI21)
    obj_op_state=$(eval $CLI22)
    
    if [ -z "$obj_admin_state" ]; then
        # CLI3="echo "\'$curl_response\'' | jq -r '\''.'$OBJECT_TYPE'[] | select(.name? == "'$OBJECT_NAME'") | "'$OBJECT_TYPE' " + .name +" is "+ .mAdminState + ", opstate="+.state.opstate'\'''
        CLI31="echo "\'$curl_response\'' | jq -r '\''.'$OBJECT_TYPE'[] | select(.name? == "'$OBJECT_NAME'") | .mAdminState'\'''
        CLI32="echo "\'$curl_response\'' | jq -r '\''.'$OBJECT_TYPE'[] | select(.name? == "'$OBJECT_NAME'") | .state.opstate'\'''
        obj_admin_state=$(eval $CLI31)
        obj_op_state=$(eval $CLI32)
    fi

    if [ ! "$obj_admin_state" = "enabled" ] || [ ! "$obj_op_state" = "up" ]; then
        COLOR=$RED
    else
        COLOR=$GREEN
    fi

    echo -e $COLOR"$OBJECT_TYPE $OBJECT_NAME: admin_state=$obj_admin_state op_state=$obj_op_state"$NC
}
##################################################################################
# Get DataPower object operational state
##################################################################################
retry() {
    DP_SEQ=$1
    DP_APIC_DOMAIN_NAME=$2
    DP_OBJECT_TYPE=$3
    DP_OBJECT_NAME=$4

    DP_USERNAME="$(getIndirectValue DP_USER_NAME_SERVER $DP_SEQ)"
    DP_PASSWORD="$(getIndirectValue DP_USER_PASSWORD_SERVER $DP_SEQ)"
    DP_ROMA_URL="$(getIndirectValue DP_ROMA_URL_SERVER $DP_SEQ)"

    for ((i=1; i<=$RETRY_MAX; i++)); do
        declare -a RESULT="$(romaGetDpOjectOpState $DP_USERNAME $DP_PASSWORD $DP_ROMA_URL $DP_APIC_DOMAIN_NAME $DP_OBJECT_TYPE $DP_OBJECT_NAME)"
        if [ "$RESULT" = "up" ]; then
            break
        else
            echo -e $PURPLE"Retry "$i"/$RETRY_MAX: Object $DP_OBJECT_TYPE $DP_OBJECT_NAME is not up, sleeping for $RETRY_INTERVAL sec"$NC
            sleep $RETRY_INTERVAL
        fi
    done

    if [ ! "$RESULT" = "up" ]; then
        echo -e $RED"The dependent object $DP_OBJECT_TYPE $DP_OBJECT_NAME is not up, aborting"$NC
        exit
    fi
}
##################################################################################
# Deploy APIC config to DP gateway
##################################################################################
deployApicConfigToDataPower() {
    NUM_OF_DPS=$1
    CUR_DP_SEQ=$2

    echo -e $BLUE"====================================================================================="
    echo -e "Deploying APIC config to DP gateway" "$(getIndirectValue DP_MGMT_IP_SERVER $CUR_DP_SEQ)"
    echo -e "====================================================================================="$NC

    CUR_DP_USERNAME="$(getIndirectValue DP_USER_NAME_SERVER $CUR_DP_SEQ)"
    CUR_DP_PASSWORD="$(getIndirectValue DP_USER_PASSWORD_SERVER $CUR_DP_SEQ)"
    CUR_DP_SOMA_URL="$(getIndirectValue DP_SOMA_URL_SERVER $CUR_DP_SEQ)"

    if [ -z "$DP_CRYPTO_ROOTCA_CERT_FILENAME" ]; then
        echo -e $PURPLE"Root CA certificate was not provided in the configuration and will not be configured."$NC
    else
        somaUploadFile $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL "default" "sharedcert" $KEYS_DIR $DP_CRYPTO_ROOTCA_CERT_FILENAME
    fi

    if [ -z "$DP_CRYPTO_INTERCA_CERT_FILENAME" ]; then
        echo -e $PURPLE"Intermediate CA certificate was not provided in the configuration and will not be configured."$NC
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

    somaConfigureApiProbe $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL 1000 60 $DP_PEERING_MGR_API_PROBE $CUR_DP_SEQ

    somaSaveDomainConfiguration $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_SOMA_URL $DP_APIC_DOMAIN_NAME
}
##################################################################################
# Verify APIC config deployment
##################################################################################
verifyApicConfigDeployment() {
    CUR_DP_SEQ=$1

    echo -e $BLUE"====================================================================================="
    echo -e "Verifying APIC config on DP gateway" "$(getIndirectValue DP_MGMT_IP_SERVER $CUR_DP_SEQ)"
    echo -e "====================================================================================="$NC

    CUR_DP_USERNAME="$(getIndirectValue DP_USER_NAME_SERVER $CUR_DP_SEQ)"
    CUR_DP_PASSWORD="$(getIndirectValue DP_USER_PASSWORD_SERVER $CUR_DP_SEQ)"
    CUR_DP_ROMA_URL="$(getIndirectValue DP_ROMA_URL_SERVER $CUR_DP_SEQ)"

    CUR_DP_MNG_HOST_ALIAS="$(getIndirectValue DP_MGMT_HOST_ALIAS_SERVER $CUR_DP_SEQ)"
    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL "default" "HostAlias" $CUR_DP_MNG_HOST_ALIAS

    CUR_DP_DATA_HOST_ALIAS="$(getIndirectValue DP_DATA_HOST_ALIAS_SERVER $CUR_DP_SEQ)"
    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL "default" "HostAlias" $CUR_DP_DATA_HOST_ALIAS

    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL "default" "Domain" $DP_APIC_DOMAIN_NAME

    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "CryptoCertificate" $DP_CRYPTO_ROOTCA_CERT_OBJ
    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "CryptoCertificate" $DP_CRYPTO_INTERCA_CERT_OBJ
    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "CryptoCertificate" $DP_CRYPTO_DP_CERT_OBJ
    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "CryptoKey" $DP_CRYPTO_DP_KEY_OBJ
    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "CryptoIdentCred" $DP_CRYPTO_DP_IDCRED_OBJ
    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "SSLServerProfile" $DP_CRYPTO_SSL_SERVER_PROFILE_OBJ
    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "SSLClientProfile" $DP_CRYPTO_SSL_CLIENT_PROFILE_OBJ

    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "GatewayPeering" $DP_PEERING_MGR_APICGW
    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "GatewayPeering" $DP_PEERING_MGR_API_RATE_LIMIT
    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "GatewayPeering" $DP_PEERING_MGR_SUBS
    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "GatewayPeering" $DP_PEERING_MGR_API_PROBE
    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "GatewayPeering" $DP_PEERING_MGR_GWS_RATE_LIMIT
    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "GatewayPeeringManager" "default"
    
    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "ConfigSequence" $DP_CONFIG_SEQUENCE_OBJ
    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "APIConnectGatewayService" "default"

    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "GatewayPeering" $DP_PEERING_MGR_TOKENS
    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "APISecurityTokenManager" "default"

    romaCheckDpOjectStatus $CUR_DP_USERNAME $CUR_DP_PASSWORD $CUR_DP_ROMA_URL $DP_APIC_DOMAIN_NAME "APIDebugProbe" "default"
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
. 99-dp-rmi-utils.sh

cd $PROJECT_DIR
echo =====================================================================================
echo "Configuring the API Connect Gateway Service on DataPower gateways"
declare -a NUM_OF_DPS="$(numOfDpGateways)"

echo "Number of DataPower gateways: "$NUM_OF_DPS

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

echo "====================================================================================="
