#!/bin/bash
##################################################################################
# before running this script the following should be configured manually:
# 1) SOMA enabled and available on the host DNS
# 2) DP cert, key, inter ca, root ca uploaded to sharedcert
# 3) review customer configuration section
##################################################################################
# Tested on:
#   2018.4.1.13
##################################################################################
# Customer configuration
##################################################################################
# Changes:
# 2022-11-11 Added somaUpdateTimeZone() function
##################################################################################

host1=dp1.company.org
host2=dp2.company.org
host3=dp3.company.org

ip1=10.20.10.111
ip2=10.20.10.112
ip3=10.20.10.113

soma_user=admin
soma_psw=admin
soma_port=5550
roma_port=5554

apic_domain_name=apiconnect
api_mng_port=3000
api_invocation_port=443

curdp_crypto_key_filename=sharedcert:///dp.company.org-privkey.pem
curdp_crypto_cert_filename=sharedcert:///dp.company.org-cert.pem
inter_ca_crypto_cert_filename=sharedcert:///IntermediateCA.pem
root_ca_crypto_cert_filename=sharedcert:///RootCA.pem

##################################################################################
# Internal configuration
##################################################################################
soma_uri=/service/mgmt/3.0
host_alias=apic_eth

curdp_crypto_key_obj=gwd_key
curdp_crypto_cert_obj=gwd_cert
inter_ca_crypto_cert_obj=inter_ca_cert
root_ca_crypto_cert_obj=root_ca_cert
curdp_id_cred_obj=gwd_id_cred
ssl_server_profile=gwd_server
ssl_client_profile=gwd_client

peering_mgr_gwd=gwd
peering_mgr_api_tokens=api-token
peering_mgr_api_probe=api-probe
peering_mgr_rate_limit=rate-limit
peering_mgr_subs=subs

timezone=UTC

DP1_SOMA_URL="https://${host1}:${soma_port}${soma_uri}"
DP2_SOMA_URL="https://${host2}:${soma_port}${soma_uri}"
DP3_SOMA_URL="https://${host3}:${soma_port}${soma_uri}"

DP1_ROMA_URL="https://${host1}:${roma_port}"
DP2_ROMA_URL="https://${host2}:${roma_port}"
DP3_ROMA_URL="https://${host3}:${roma_port}"

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
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ma="http://www.datapower.com/schemas/management">
   <SOAP-ENV:Body>
        <ma:request domain="$DOMAIN_NAME">
            <ma:set-config>
                <CryptoIdentCred name="$OBJ_NAME">
                    <mAdminState>enabled</mAdminState>
                    <Key>$curdp_crypto_key_obj</Key>
                    <Certificate>$curdp_crypto_cert_obj</Certificate>
                    <CA>$inter_ca_crypto_cert_obj</CA>
                    <CA>$root_ca_crypto_cert_obj</CA>
                </CryptoIdentCred>
            </ma:set-config>
        </ma:request>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
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
# Create API Security Token Manager
##################################################################################
somaCreateApicSecurityTokenManager() {
    SOMA_USER=$1
    SOMA_PSW=$2
    SOMA_URL=$3
    DOMAIN_NAME=$4
    SOMA_REQ=$(cat <<-EOF
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ma="http://www.datapower.com/schemas/management">
   <SOAP-ENV:Body>
        <ma:request domain="$DOMAIN_NAME">
            <ma:set-config>
                <APISecurityTokenManager name="default">
                    <mAdminState>enabled</mAdminState>
                    <GatewayPeering>$peering_mgr_api_tokens</GatewayPeering>
                </APISecurityTokenManager>
            </ma:set-config>
        </ma:request>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
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
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ma="http://www.datapower.com/schemas/management">
   <SOAP-ENV:Body>
        <ma:request domain="$DOMAIN_NAME">
            <ma:set-config>
                <CryptoCertificate name="$OBJ_NAME">
                    <mAdminState>enabled</mAdminState>
                    <Filename>$FILE_NAME</Filename>
                    <Password></Password>
                    <PasswordAlias>off</PasswordAlias>
                    <Alias></Alias>
                    <IgnoreExpiration>off</IgnoreExpiration>
                </CryptoCertificate>
            </ma:set-config>
        </ma:request>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
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
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ma="http://www.datapower.com/schemas/management">
   <SOAP-ENV:Body>
        <ma:request domain="$DOMAIN_NAME">
            <ma:set-config>
                <CryptoKey name="$OBJ_NAME">
                    <mAdminState>enabled</mAdminState>
                    <Filename>$FILE_NAME</Filename>
                    <Password></Password>
                    <PasswordAlias>off</PasswordAlias>
                    <Alias></Alias>
                </CryptoKey>
            </ma:set-config>
        </ma:request>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
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
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ma="http://www.datapower.com/schemas/management">
   <SOAP-ENV:Body>
        <ma:request domain="$DOMAIN_NAME">
            <ma:do-action>
                <SaveConfig></SaveConfig>
            </ma:do-action>
        </ma:request>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
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
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ma="http://www.datapower.com/schemas/management">
   <SOAP-ENV:Body>
        <ma:request domain="default">
            <ma:set-config>
                <Domain name="$DOMAIN_NAME">
                    <mAdminState>enabled</mAdminState>
                    <UserSummary>api connect domain</UserSummary>
                    <NeighborDomain>default</NeighborDomain>
                </Domain>
            </ma:set-config>
        </ma:request>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
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
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ma="http://www.datapower.com/schemas/management">
   <SOAP-ENV:Body>
        <ma:request domain="default">
            <ma:set-config>
                <HostAlias name="$ALIAS_NAME">
                    <mAdminState>enabled</mAdminState>
                    <UserSummary>host alias</UserSummary>
                    <IPAddress>$IPADDRESS</IPAddress>
                </HostAlias>
            </ma:set-config>
        </ma:request>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
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
                    <LocalTimeZone>$timezone</LocalTimeZone>
                </TimeSettings>
            </ma:modify-config>
        </ma:request>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
EOF
)
    echo "====================================================================================="
    echo "Setting time zone to " $TIMEZONE
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
    SSL_SERVER_PROFILE=$5
    SOMA_REQ=$(cat <<-EOF
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ma="http://www.datapower.com/schemas/management">
   <SOAP-ENV:Body>
        <ma:request domain="$DOMAIN_NAME">
            <ma:set-config>
                <SSLServerProfile name="$SSL_SERVER_PROFILE">
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
                    <Idcred>$curdp_id_cred_obj</Idcred>
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
            </ma:set-config>
        </ma:request>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Creating SSL/TLS Server" $SSL_SERVER_PROFILE
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
    SSL_CLIENT_PROFILE=$5
    SOMA_REQ=$(cat <<-EOF
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ma="http://www.datapower.com/schemas/management">
   <SOAP-ENV:Body>
        <ma:request domain="$DOMAIN_NAME">
            <ma:set-config>
                <SSLClientProfile name="$SSL_CLIENT_PROFILE">
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
                    <Idcred>$curdp_id_cred_obj</Idcred>
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
            </ma:set-config>
        </ma:request>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
EOF
)

    echo "====================================================================================="
    echo "Creating SSL/TLS ServClienter" $SSL_CLIENT_PROFILE
    echo "====================================================================================="
    curl -k -X POST -u $SOMA_USER:$SOMA_PSW $SOMA_URL -d "${SOMA_REQ}"
    echo ""
    echo "====================================================================================="
}
##################################################################################
# Create Gateway Peering
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
    SOMA_REQ=$(cat <<-EOF
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ma="http://www.datapower.com/schemas/management">
   <SOAP-ENV:Body>
        <ma:request domain="$DOMAIN_NAME">
            <ma:set-config>
                <GatewayPeering name="$PEERING_NAME">
                    <mAdminState>enabled</mAdminState>
                    <UserSummary>APIC peering</UserSummary>
                    <LocalAddress>$host_alias</LocalAddress>
                    <LocalPort>$LOCAL_PORT</LocalPort>
                    <MonitorPort>$MONITOR_PORT</MonitorPort>
                    <EnablePeerGroup>on</EnablePeerGroup>
                    <Peers>$PEER2</Peers>
                    <Peers>$PEER3</Peers>
                    <Priority>80</Priority>
                    <EnableSSL>on</EnableSSL>
                    <Idcred>$curdp_id_cred_obj</Idcred>
                    <Valcred></Valcred>
                    <PersistenceLocation>memory</PersistenceLocation>
                    <LocalDirectory>local:///</LocalDirectory>
                </GatewayPeering>
            </ma:set-config>
        </ma:request>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
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
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ma="http://www.datapower.com/schemas/management">
   <SOAP-ENV:Body>
        <ma:request domain="$DOMAIN_NAME">
            <ma:set-config>
                <GatewayPeeringManager name="default">
                    <mAdminState>enabled</mAdminState>
                    <UserSummary>APIC gw peering manager</UserSummary>
                    <APIConnectGatewayService>$peering_mgr_gwd</APIConnectGatewayService>
                    <RateLimit>$RATE_LIMIT</RateLimit>
                    <Subscription>$SUBS</Subscription>
                    <RatelimitModule>default-gateway-peering</RatelimitModule>
                </GatewayPeeringManager>
            </ma:set-config>
        </ma:request>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
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
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ma="http://www.datapower.com/schemas/management">
   <SOAP-ENV:Body>
        <ma:request domain="$DOMAIN_NAME">
            <ma:set-config>
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
            </ma:set-config>
        </ma:request>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
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
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ma="http://www.datapower.com/schemas/management">
   <SOAP-ENV:Body>
        <ma:request domain="$DOMAIN_NAME">
            <ma:set-config>
                <APIConnectGatewayService name="default">
                    <mAdminState>enabled</mAdminState>
                    <UserSummary>APIC gw service</UserSummary>
                    <LocalAddress>$host_alias</LocalAddress>
                    <LocalPort>$api_mng_port</LocalPort>
                    <SSLClient>$ssl_client_profile</SSLClient>
                    <SSLServer>$ssl_server_profile</SSLServer>
                    <APIGatewayAddress>$host_alias</APIGatewayAddress>
                    <APIGatewayPort>$api_invocation_port</APIGatewayPort>
                    <GatewayPeering>default-gateway-peering</GatewayPeering>
                    <GatewayPeeringManager>default</GatewayPeeringManager>
                    <V5CompatibilityMode>off</V5CompatibilityMode>
                    <UserDefinedPolicies></UserDefinedPolicies>
                    <V5CSlmMode>autounicast</V5CSlmMode>
                    <IPMulticast></IPMulticast>
                    <IPUnicast></IPUnicast>
                </APIConnectGatewayService>
            </ma:set-config>
        </ma:request>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
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
# Main program
##################################################################################

# curl -k -u $soma_user:$soma_psw -X DELETE $DP1_ROMA_URL/mgmt/config/default/Domain/$apic_domain_name
# curl -k -u $soma_user:$soma_psw -X DELETE $DP2_ROMA_URL/mgmt/config/default/Domain/$apic_domain_name
# curl -k -u $soma_user:$soma_psw -X DELETE $DP3_ROMA_URL/mgmt/config/default/Domain/$apic_domain_name

somaCreateHostAlias $soma_user $soma_psw $DP1_SOMA_URL $host_alias $ip1
somaCreateHostAlias $soma_user $soma_psw $DP2_SOMA_URL $host_alias $ip2
somaCreateHostAlias $soma_user $soma_psw $DP3_SOMA_URL $host_alias $ip3

somaUpdateTimeZone $soma_user $soma_psw $DP1_SOMA_URL
somaUpdateTimeZone $soma_user $soma_psw $DP2_SOMA_URL
somaUpdateTimeZone $soma_user $soma_psw $DP3_SOMA_URL

somaCreateDomain $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name
somaCreateDomain $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name
somaCreateDomain $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name

somaSaveDomainConfiguration $soma_user $soma_psw $DP1_SOMA_URL "default"
somaSaveDomainConfiguration $soma_user $soma_psw $DP2_SOMA_URL "default"
somaSaveDomainConfiguration $soma_user $soma_psw $DP3_SOMA_URL "default"

somaCreateCryptoKey $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name $curdp_crypto_key_obj $curdp_crypto_key_filename
somaCreateCryptoKey $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name $curdp_crypto_key_obj $curdp_crypto_key_filename
somaCreateCryptoKey $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name $curdp_crypto_key_obj $curdp_crypto_key_filename

somaCreateCryptoCert $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name $curdp_crypto_cert_obj $curdp_crypto_cert_filename
somaCreateCryptoCert $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name $curdp_crypto_cert_obj $curdp_crypto_cert_filename
somaCreateCryptoCert $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name $curdp_crypto_cert_obj $curdp_crypto_cert_filename

somaCreateCryptoCert $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name $inter_ca_crypto_cert_obj $inter_ca_crypto_cert_filename
somaCreateCryptoCert $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name $inter_ca_crypto_cert_obj $inter_ca_crypto_cert_filename
somaCreateCryptoCert $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name $inter_ca_crypto_cert_obj $inter_ca_crypto_cert_filename

somaCreateCryptoCert $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name $root_ca_crypto_cert_obj $root_ca_crypto_cert_filename
somaCreateCryptoCert $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name $root_ca_crypto_cert_obj $root_ca_crypto_cert_filename
somaCreateCryptoCert $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name $root_ca_crypto_cert_obj $root_ca_crypto_cert_filename

somaCreateCryptoIdCred $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name $curdp_id_cred_obj
somaCreateCryptoIdCred $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name $curdp_id_cred_obj
somaCreateCryptoIdCred $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name $curdp_id_cred_obj

somaCreateSslServer $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name $ssl_server_profile
somaCreateSslServer $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name $ssl_server_profile
somaCreateSslServer $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name $ssl_server_profile

somaCreateSslClient $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name $ssl_client_profile
somaCreateSslClient $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name $ssl_client_profile
somaCreateSslClient $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name $ssl_client_profile

somaCreateGatewayPeering $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name $host2 $host3 $peering_mgr_gwd 16380 26380 80
somaCreateGatewayPeering $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name $host1 $host3 $peering_mgr_gwd 16380 26380 90
somaCreateGatewayPeering $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name $host2 $host1 $peering_mgr_gwd 16380 26380 100

somaCreateGatewayPeering $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name $host2 $host3 $peering_mgr_rate_limit 16383 26383 80
somaCreateGatewayPeering $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name $host1 $host3 $peering_mgr_rate_limit 16383 26383 90
somaCreateGatewayPeering $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name $host2 $host1 $peering_mgr_rate_limit 16383 26383 100

somaCreateGatewayPeering $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name $host2 $host3 $peering_mgr_subs 16384 26384 80
somaCreateGatewayPeering $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name $host1 $host3 $peering_mgr_subs 16384 26384 90
somaCreateGatewayPeering $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name $host2 $host1 $peering_mgr_subs 16384 26384 100

somaCreateGatewayPeering $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name $host2 $host3 $peering_mgr_api_probe 16382 26382 80
somaCreateGatewayPeering $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name $host1 $host3 $peering_mgr_api_probe 16382 26382 90
somaCreateGatewayPeering $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name $host2 $host1 $peering_mgr_api_probe 16382 26382 100

somaCreateGatewayPeering $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name $host2 $host3 $peering_mgr_api_tokens 16385 26385 80
somaCreateGatewayPeering $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name $host1 $host3 $peering_mgr_api_tokens 16385 26385 90
somaCreateGatewayPeering $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name $host2 $host1 $peering_mgr_api_tokens 16385 26385 100

somaCreateGatewayPeeringManager $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name $peering_mgr_rate_limit $peering_mgr_subs
somaCreateGatewayPeeringManager $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name $peering_mgr_rate_limit $peering_mgr_subs
somaCreateGatewayPeeringManager $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name $peering_mgr_rate_limit $peering_mgr_subs

somaCreateConfigSequence $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name
somaCreateConfigSequence $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name
somaCreateConfigSequence $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name

somaCreateApiConnectGatewayService $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name
somaCreateApiConnectGatewayService $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name
somaCreateApiConnectGatewayService $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name

somaCreateApicSecurityTokenManager $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name
somaCreateApicSecurityTokenManager $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name
somaCreateApicSecurityTokenManager $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name

somaSaveDomainConfiguration $soma_user $soma_psw $DP1_SOMA_URL $apic_domain_name
somaSaveDomainConfiguration $soma_user $soma_psw $DP2_SOMA_URL $apic_domain_name
somaSaveDomainConfiguration $soma_user $soma_psw $DP3_SOMA_URL $apic_domain_name
