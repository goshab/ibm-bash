#!/bin/bash

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
        # echo -e "Result: "$GREEN"Success"$NC
        log_success "Success"
        if [ "$DEBUG" = "true" ]; then
            echo Response
            echo $response
        fi
   else
        # echo -e $RED"Error, DataPower SOMA response:"$NC
        log_error "Error, DataPower SOMA response:"
        log_error $response
        # echo -e ${response}$NC
        exit
    fi
}
##################################################################################
# Configure NTP service
##################################################################################
        # <NTPService name="NTP Service">
        #     <mAdminState>enabled</mAdminState>
        #     <Mode>on</Mode>
        #     <RemoteServer>10.232.217.1</RemoteServer>
        #     <RefreshInterval>900</RefreshInterval>
        # </NTPService>
##################################################################################
# Configure domain Statistics
##################################################################################
somaConfigureDomainStatistics() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4

    log_title "Configuring Statistics for $DOMAIN_NAME domain"

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
   <soapenv:Body>
        <dp:request domain="$DOMAIN_NAME">
            <dp:set-config>
                <Statistics name="default">
                    <mAdminState>enabled</mAdminState>
                    <LoadInterval>1000</LoadInterval>
                </Statistics>
            </dp:set-config>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    # echo "Uploading $LOCAL_FOLDER/$FILE_NAME file to" $DEST_FILE_PATH
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
}
##################################################################################
# Configure Throttler
##################################################################################
        # <Throttler name="Throttler">
        #     <mAdminState>enabled</mAdminState>
        #     <Mode>on</Mode>
        #     <ThrottleAt>20</ThrottleAt>
        #     <TerminateAt>5</TerminateAt>
        # </Throttler>
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

    log_title "Uploading $LOCAL_FOLDER/$FILE_NAME file to" $DEST_FILE_PATH
    # echo "Uploading $LOCAL_FOLDER/$FILE_NAME file to" $DEST_FILE_PATH
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
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

    log_title "Creating Crypto Identification Credentials $OBJ_NAME"

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

    # echo "Creating crypto id credentials" $OBJ_NAME
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
}
##################################################################################
# Set UTC time zone
##################################################################################
somaUpdateTimeZone() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DP_TIMEZONE=$4

    log_title "Setting time zone to $DP_TIMEZONE"

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
    # echo "Setting time zone to "$DP_TIMEZONE
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
}
##################################################################################
# Create API Security Token Manager
##################################################################################
somaCreateApicSecurityTokenManager() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4

    log_title "Creating API Security Token Manager"

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

    # echo "Creating API Security Token Manager"
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
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

    log_title "Creating Crypto Certificate $OBJ_NAME"

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

    # echo "Creating crypto cert" $OBJ_NAME
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
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

    log_title "Creating crypto key $OBJ_NAME"

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

    # echo "Creating crypto key" $OBJ_NAME
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
}
##################################################################################
# Save domain configuration
##################################################################################
somaSaveDomainConfiguration() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4

    log_title "Save domain configuration $DOMAIN_NAME"

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

    # echo "Save domain configuration" $DOMAIN_NAME
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
}
##################################################################################
# Create new DataPower application domain
##################################################################################
somaCreateDomain() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4

    log_title "Creating domain $DOMAIN_NAME"

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

    # echo "Creating domain" $DOMAIN_NAME
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
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

    log_title "Creating Host Aliases $ALIAS_NAME as $IPADDRESS"

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
    # echo "Creating Host Aliases" $ALIAS_NAME "as" $IPADDRESS
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
}
##################################################################################
# Configure NTP Service
##################################################################################
somaConfigureNtpService() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    NTP_IP=$4

    log_title "Configuring NTP Service"

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
    # echo "Configuring NTP Service"
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
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
    # DP_SEQ=$7

    log_title "Configuring API Probe"
    # echo "Configuring API Probe"

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

    # retry $DP_SEQ $DP_APIC_DOMAIN_NAME "GatewayPeering" $GATEWAY_PEERING

    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
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

    log_title "Configuring Password Map Alias $OBJ_NAME"

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
    # echo "Configuring Password Map Alias "$OBJ_NAME
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
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

    log_title "Creating SSL Server Profile $SSLSERVERPROFILE"

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

    # echo "Creating SSL Server Profile" $SSLSERVERPROFILE
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
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

    log_title "Creating SSL Client Profile $SSLCLIENTPROFILE"

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

    # echo "Creating SSL Client Profile" $SSLCLIENTPROFILE
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
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

    log_title "Creating Gateway Peering $PEERING_NAME"

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

    # echo "Creating Gateway Peering" $PEERING_NAME
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
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

    log_title "Creating Gateway Peering Manager"

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

    # echo "Creating Gateway Peering Manager"
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
}
##################################################################################
# Create Config Sequence
##################################################################################
somaCreateConfigSequence() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DOMAIN_NAME=$4

    log_title "Creating Config Sequence"

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

    # echo "Creating Config Sequence"
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
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

    log_title "Creating API Connect Gateway Service"
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

    # echo "Creating API Connect Gateway Service"
    runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}"
    echo "====================================================================================="
}