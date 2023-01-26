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
echo "Configuring the Gateway service"
echo "================================================================================"

##################################################################################
# Internal configuration
##################################################################################
if [ -z "$DP_SERVER1_USER_NAME" ]; then
    read -p 'DataPower user name: ' DP_SERVER1_USER_NAME
else
    echo "DataPower user name: "$DP_SERVER1_USER_NAME
fi

if [ -z "$DP_SERVER1_USER_PASSWORD" ]; then
    read -sp 'DataPower user password: ' DP_SERVER1_USER_PASSWORD
    echo
fi
##################################################################################
# Is DP 
##################################################################################
isDpClustrt(){
numOfDpGateways(){
    SEQ = 1

    while [ true ]; do
        DP_SERVER1_MGMT_IP
        if [ -z "$DP_SERVER${SEQ}_MGMT_IP" ]; then
            exit
        fi
        SEQ = SEQ + 1
    done

    echo result

}
##################################################################################
# Upload file
##################################################################################
somaUploadFile() {
    SOMA_USER=$1
    SOMA_PSW=$2
    SOMA_URL=$3
    DOMAIN_NAME=$4
    DP_FOLDER=$5
    FILE_NAME=$6
    LOCAL_FOLDER=$7

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
    echo "Uploading file to" $DEST_FILE_PATH
    echo "====================================================================================="
    curl -k -X POST -u $SOMA_USER:$SOMA_PSW $SOMA_URL -d "${SOMA_REQ}"
    echo ""
    echo "====================================================================================="
}
##################################################################################
# Create Crypto ID Cred
##################################################################################
somaCreateCryptoIdCred() {
    SOMA_USER=$1
    SOMA_PSW=$2
    SOMA_URL=$3
    DOMAIN_NAME=$4
    OBJ_NAME=$5
    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <CryptoIdentCred name="$OBJ_NAME">
                    <mAdminState>enabled</mAdminState>
                    <Key>$DP_CRYPTO_DP_KEY_OBJ</Key>
                    <Certificate>$DP_CRYPTO_DP_CERT_OBJ</Certificate>
                    <CA>$DP_CRYPTO_INTERCA_CERT_OBJ</CA>
                    <CA>$DP_CRYPTO_ROOTCA_CERT_OBJ</CA>
                </CryptoIdentCred>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Creating crypto id cred" $OBJ_NAME
    echo "====================================================================================="
    curl -k -X POST -u $SOMA_USER:$SOMA_PSW $SOMA_URL -d "${SOMA_REQ}"
    echo ""
    echo "====================================================================================="
}
##################################################################################
# Set UTC time zone
##################################################################################
somaUpdateTimeZone() {
    SOMA_USER=$1
    SOMA_PSW=$2
    SOMA_URL=$3
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
    echo "Setting time zone to " $DP_TIMEZONE
    echo "====================================================================================="
    curl -k -X POST -u $SOMA_USER:$SOMA_PSW $SOMA_URL -d "${SOMA_REQ}"
    echo ""
    echo "====================================================================================="
}
##################################################################################
# Create API Security Token Manager
##################################################################################
somaCreateApicSecurityTokenManager() {
    SOMA_USER=$1
    SOMA_PSW=$2
    SOMA_URL=$3
    DOMAIN_NAME=$4
    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <APISecurityTokenManager name="default">
                    <mAdminState>enabled</mAdminState>
                    <GatewayPeering>$DP_PEERING_MGR_API_TOKENS</GatewayPeering>
                </APISecurityTokenManager>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Creating API Security Token Manager"
    echo "====================================================================================="
    curl -k -X POST -u $SOMA_USER:$SOMA_PSW $SOMA_URL -d "${SOMA_REQ}"
    echo ""
    echo "====================================================================================="
}
##################################################################################
# Create Crypto Cert
##################################################################################
somaCreateCryptoCert() {
    SOMA_USER=$1
    SOMA_PSW=$2
    SOMA_URL=$3
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
    echo "====================================================================================="
    curl -k -X POST -u $SOMA_USER:$SOMA_PSW $SOMA_URL -d "${SOMA_REQ}"
    echo ""
    echo "====================================================================================="
}
##################################################################################
# Create Crypto Key
##################################################################################
somaCreateCryptoKey() {
    SOMA_USER=$1
    SOMA_PSW=$2
    SOMA_URL=$3
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
    echo "====================================================================================="
    curl -k -X POST -u $SOMA_USER:$SOMA_PSW $SOMA_URL -d "${SOMA_REQ}"
    echo ""
    echo "====================================================================================="
}
##################################################################################
# Save domain configuration
##################################################################################
somaSaveDomainConfiguration() {
    SOMA_USER=$1
    SOMA_PSW=$2
    SOMA_URL=$3
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
    echo "====================================================================================="
    curl -k -X POST -u $SOMA_USER:$SOMA_PSW $SOMA_URL -d "${SOMA_REQ}"
    echo ""
    echo "====================================================================================="
}
##################################################################################
# Create domain
##################################################################################
somaCreateDomain() {
    SOMA_USER=$1
    SOMA_PSW=$2
    SOMA_URL=$3
    DOMAIN_NAME=$4
    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="default">
            <dp:set-config>
                <Domain name="$DOMAIN_NAME">
                    <mAdminState>enabled</mAdminState>
                    <UserSummary>api connect domain</UserSummary>
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
    echo "====================================================================================="
    curl -k -X POST -u $SOMA_USER:$SOMA_PSW $SOMA_URL -d "${SOMA_REQ}"
    echo ""
    echo "====================================================================================="
}
##################################################################################
# Create Host Aliases
##################################################################################
somaCreateHostAlias() {
    SOMA_USER=$1
    SOMA_PSW=$2
    SOMA_URL=$3
    ALIAS_NAME=$4
    IPADDRESS=$5
    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="default">
            <dp:set-config>
                <HostAlias name="$ALIAS_NAME">
                    <mAdminState>enabled</mAdminState>
                    <UserSummary>host alias</UserSummary>
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
    echo "====================================================================================="
    curl -k -X POST -u $SOMA_USER:$SOMA_PSW $SOMA_URL -d "${SOMA_REQ}"
    echo ""
    echo "====================================================================================="
}
##################################################################################
# Create SSL/TLS Server
##################################################################################
somaCreateSslServer() {
    SOMA_USER=$1
    SOMA_PSW=$2
    SOMA_URL=$3
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
    echo "Creating SSL/TLS Server" $SSLSERVERPROFILE
    echo "====================================================================================="
    curl -k -X POST -u $SOMA_USER:$SOMA_PSW $SOMA_URL -d "${SOMA_REQ}"
    echo ""
    echo "====================================================================================="
}
##################################################################################
# Create SSL/TLS Server
##################################################################################
somaCreateSslClient() {
    SOMA_USER=$1
    SOMA_PSW=$2
    SOMA_URL=$3
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
    echo "Creating SSL/TLS ServClienter" $SSLCLIENTPROFILE
    echo "====================================================================================="
    curl -k -X POST -u $SOMA_USER:$SOMA_PSW $SOMA_URL -d "${SOMA_REQ}"
    echo ""
    echo "====================================================================================="
}
##################################################################################
# Create Gateway Peering
somaCreateGatewayPeering 
1 $DP_SERVER1_USER_NAME 
2 $DP_SERVER1_USER_PASSWORD 
3 $DP_SERVER1_SOMA_URL 
4 $DP_APIC_DOMAIN_NAME 
5 $DP_HOST2 
6 $DP_HOST3 
7 $DP_PEERING_MGR_GWD 
8 16380 
9 26380 
10 $PRIORITY

##################################################################################
somaCreateGatewayPeering() {
    SOMA_USER=$1
    SOMA_PSW=$2
    SOMA_URL=$3
    DOMAIN_NAME=$4
    PEER2=$5
    PEER3=$6
    PEERING_NAME=$7
    LOCAL_PORT=$8
    MONITOR_PORT=$9
    PRIORITY=$10
    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <GatewayPeering name="$PEERING_NAME">
                    <mAdminState>enabled</mAdminState>
                    <UserSummary>APIC peering</UserSummary>
                    <LocalAddress>$DP_SERVER1_MGMT_HOST_ALIAS</LocalAddress>
                    <LocalPort>$LOCAL_PORT</LocalPort>
                    <MonitorPort>$MONITOR_PORT</MonitorPort>
                    <EnablePeerGroup>on</EnablePeerGroup>
                    <Peers>$PEER2</Peers>
                    <Peers>$PEER3</Peers>
                    <Priority>$PRIORITY</Priority>
                    <EnableSSL>on</EnableSSL>
                    <Idcred>$DP_CRYPTO_DP_IDCRED_OBJ</Idcred>
                    <Valcred></Valcred>
                    <PersistenceLocation>memory</PersistenceLocation>
                    <LocalDirectory>local:///</LocalDirectory>
                </GatewayPeering>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Creating Gateway Peering" $PEERING_NAME
    echo "====================================================================================="
    curl -k -X POST -u $SOMA_USER:$SOMA_PSW $SOMA_URL -d "${SOMA_REQ}"
    echo ""
    echo "====================================================================================="
}
##################################################################################
# Create Gateway Peering Manager
##################################################################################
somaCreateGatewayPeeringManager() {
    SOMA_USER=$1
    SOMA_PSW=$2
    SOMA_URL=$3
    DOMAIN_NAME=$4
    RATE_LIMIT=$5
    SUBS=$6
    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <GatewayPeeringManager name="default">
                    <mAdminState>enabled</mAdminState>
                    <UserSummary>APIC gw peering manager</UserSummary>
                    <APIConnectGatewayService>$DP_PEERING_MGR_GWD</APIConnectGatewayService>
                    <RateLimit>$RATE_LIMIT</RateLimit>
                    <Subscription>$SUBS</Subscription>
                    <RatelimitModule>default-gateway-peering</RatelimitModule>
                </GatewayPeeringManager>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Creating Gateway Peering Manager"
    echo "====================================================================================="
    curl -k -X POST -u $SOMA_USER:$SOMA_PSW $SOMA_URL -d "${SOMA_REQ}"
    echo ""
    echo "====================================================================================="
}
##################################################################################
# Create Config Sequence
##################################################################################
somaCreateConfigSequence() {
    SOMA_USER=$1
    SOMA_PSW=$2
    SOMA_URL=$3
    DOMAIN_NAME=$4
    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <ConfigSequence name="apiconnect">
                    <mAdminState>enabled</mAdminState>
                    <UserSummary>API Connect Configuration</UserSummary>
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
    echo "====================================================================================="
    curl -k -X POST -u $SOMA_USER:$SOMA_PSW $SOMA_URL -d "${SOMA_REQ}"
    echo ""
    echo "====================================================================================="
}
##################################################################################
# Create API Connect Gateway Service
##################################################################################
somaCreateApiConnectGatewayService() {
    SOMA_USER=$1
    SOMA_PSW=$2
    SOMA_URL=$3
    DOMAIN_NAME=$4
    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <APIConnectGatewayService name="default">
                    <mAdminState>enabled</mAdminState>
                    <UserSummary>APIC gw service</UserSummary>
                    <LocalAddress>$DP_SERVER1_MGMT_HOST_ALIAS</LocalAddress>
                    <LocalPort>$DP_GWD_ENDPOINT_PORT</LocalPort>
                    <SSLClient>$DP_CRYPTO_SSL_CLIENT_PROFILE_OBJ</SSLClient>
                    <SSLServer>$DP_CRYPTO_SSL_SERVER_PROFILE_OBJ</SSLServer>
                    <APIGatewayAddress>$DP_SERVER1_MGMT_HOST_ALIAS</APIGatewayAddress>
                    <APIGatewayPort>$DP_GW_ENDPOINT_PORT</APIGatewayPort>
                    <GatewayPeering>default-gateway-peering</GatewayPeering>
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
    echo "====================================================================================="
    curl -k -X POST -u $SOMA_USER:$SOMA_PSW $SOMA_URL -d "${SOMA_REQ}"
    echo ""
    echo "====================================================================================="
}
##################################################################################
# Delete domain
##################################################################################
romaDeleteDomain() {
    SOMA_USER=$1
    SOMA_PSW=$2
    ROMA_URL=$3
    DOMAIN_NAME=$4

    echo "====================================================================================="
    echo "Deleting application domain" $DOMAIN_NAME
    echo "====================================================================================="
    curl -k -u $SOMA_USER:$SOMA_PSW -X DELETE "${ROMA_URL}/mgmt/config/default/Domain/${DOMAIN_NAME}"
    echo ""
    echo "====================================================================================="
}
##################################################################################
# Create user
#   NEW_USER_ACCESS:
#       privileged
##################################################################################
romaCreateUser() {
    SOMA_USER=$1
    SOMA_PSW=$2
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
    echo "Creating user" $DOMAIN_NAME
    echo "====================================================================================="
    curl -k -u $SOMA_USER:$SOMA_PSW -X PUT "${ROMA_URL}/mgmt/config/default/User/${NEW_USER_NAME}" -d "${ROMA_REQ}"
    echo ""
    echo "====================================================================================="
}

##################################################################################
# Deploy APIC config to DP gateway
##################################################################################
deployApicConfigToDataPower() {
    DP_HOST1=$1
    DP_IP1=$2
    PRIORITY=$3
    DP_HOST2=$4
    DP_HOST3=$5

    echo "====================================================================================="
    echo "Deploying APIC config to DP gateway" $DP_HOST1
    echo "====================================================================================="

    # somaUploadFile $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL "default" "sharedcert" $DP_CRYPTO_ROOTCA_CERT_FILENAME $KEYS_DIR
    # somaUploadFile $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL "default" "sharedcert" $DP_CRYPTO_INTERCA_CERT_FILENAME $KEYS_DIR
    # somaUploadFile $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL "default" "sharedcert" $DP_CRYPTO_DP_CERT_FILENAME $KEYS_DIR
    # somaUploadFile $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL "default" "sharedcert" $DP_CRYPTO_DP_PRIVKEY_FILENAME $KEYS_DIR

    # somaCreateHostAlias $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_SERVER1_MGMT_HOST_ALIAS $DP_IP1
    # somaCreateDomain $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME
    # somaCreateDomain $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME
    # somaUpdateTimeZone $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL
    # somaSaveDomainConfiguration $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL "default"

    # somaCreateCryptoCert $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_CRYPTO_ROOTCA_CERT_OBJ "sharedcert:///${DP_CRYPTO_ROOTCA_CERT_FILENAME}"
    # somaCreateCryptoCert $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_CRYPTO_INTERCA_CERT_OBJ "sharedcert:///${DP_CRYPTO_INTERCA_CERT_FILENAME}"
    # somaCreateCryptoCert $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_CRYPTO_DP_CERT_OBJ "sharedcert:///${DP_CRYPTO_DP_CERT_FILENAME}"
    # somaCreateCryptoKey $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_CRYPTO_DP_KEY_OBJ "sharedcert:///${DP_CRYPTO_DP_PRIVKEY_FILENAME}"
    # somaCreateCryptoIdCred $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_CRYPTO_DP_IDCRED_OBJ
    # somaCreateSslServer $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_CRYPTO_SSL_SERVER_PROFILE_OBJ
    # somaCreateSslClient $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_CRYPTO_SSL_CLIENT_PROFILE_OBJ

set -x
# if not cluster - dp_host2 and dp_host3 are empty
    somaCreateGatewayPeering $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_HOST2 $DP_HOST3 $DP_PEERING_MGR_GWD 16380 26380 $PRIORITY
set +x
exit
    somaCreateGatewayPeering $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_HOST2 $DP_HOST3 $DP_PEERING_MGR_API_PROBE 16382 26382 $PRIORITY
    somaCreateGatewayPeering $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_HOST2 $DP_HOST3 $DP_PEERING_MGR_API_RATE_LIMIT 16383 26383 $PRIORITY
    somaCreateGatewayPeering $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_HOST2 $DP_HOST3 $DP_PEERING_MGR_SUBS 16384 26384 $PRIORITY
    somaCreateGatewayPeering $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_HOST2 $DP_HOST3 $DP_PEERING_MGR_API_TOKENS 16385 26385 $PRIORITY
    somaCreateGatewayPeeringManager $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME $DP_PEERING_MGR_API_RATE_LIMIT $DP_PEERING_MGR_SUBS
    somaCreateConfigSequence $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME
    somaCreateApiConnectGatewayService $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME
    somaCreateApicSecurityTokenManager $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME
    somaSaveDomainConfiguration $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_SOMA_URL $DP_APIC_DOMAIN_NAME
}
##################################################################################

# romaDeleteDomain $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD $DP_SERVER1_ROMA_URL $DP_APIC_DOMAIN_NAME
deployApicConfigToDataPower $DP_SERVER1_MGMT_HOSTNAME $DP_SERVER1_MGMT_IP $DP_GWD_PEERING_PRIORITY_SERVER1 $DP_SERVER2_MGMT_HOSTNAME $DP_SERVER3_MGMT_HOSTNAME

# romaDeleteDomain $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD "https://${DP_SERVER2_MGMT_HOSTNAME}:${dp_roma_port}" $DP_APIC_DOMAIN_NAME
# deployApicConfigToDataPower $DP_SERVER2_MGMT_HOSTNAME $DP_SERVER2_MGMT_IP $DP_GWD_PEERING_PRIORITY_SERVER2 $DP_SERVER1_MGMT_HOSTNAME $DP_SERVER3_MGMT_HOSTNAME

# romaDeleteDomain $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD "https://${DP_SERVER3_MGMT_HOSTNAME}:${dp_roma_port}" $DP_APIC_DOMAIN_NAME
# deployApicConfigToDataPower $DP_SERVER3_MGMT_HOSTNAME $DP_SERVER3_MGMT_IP $DP_GWD_PEERING_PRIORITY_SERVER3 $DP_SERVER1_MGMT_HOSTNAME $DP_SERVER2_MGMT_HOSTNAME

# exit

##################################################################################
# DPOD config
##################################################################################
set -x
# romaCreateUser $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD "https://${DP_SERVER1_MGMT_HOSTNAME}:${dp_roma_port}" "dpod1" "newpassword" "privileged"
# romaCreateUser $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD "https://${DP_SERVER2_MGMT_HOSTNAME}:${dp_roma_port}" "dpod" "newpassword" "privileged"
# romaCreateUser $DP_SERVER1_USER_NAME $DP_SERVER1_USER_PASSWORD "https://${DP_SERVER3_MGMT_HOSTNAME}:${dp_roma_port}" "dpod" "newpassword" "privileged"



