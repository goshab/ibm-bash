#!/bin/bash
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
. ../../utils/utils.sh
log_title "Automated deployment of Linux form factor DataPower gateway"

echo "==================================================="
log_title "Connecting to $DP_LINUX_SERVER0"
ssh -l $DP_LINUX_ROOT_USER_SERVER0 -i $USER_SSH_PRIVATE_KEY $DP_LINUX_SERVER0 <<EOF1
echo "==================================================="
echo "Installing DataPower Linux service"
echo "==================================================="
cd /tmp
DP_FILES=\$(ls idg*image*.rpm idg*common*.rpm)
yum -y install \$DP_FILES
echo "==================================================="
echo "Configuring DataPower"
echo "==================================================="
cp /opt/ibm/datapower/datapower.conf /opt/ibm/datapower/datapower.conf_org2
sed -i '$ a DataPowerImageSize=8G' /opt/ibm/datapower/datapower.conf
sed -i '$ a DataPowerMemoryLimit=8192 MiB' /opt/ibm/datapower/datapower.conf
sed -i '$ a DataPowerConfigDir=/opt/ibm/datapower/config' /opt/ibm/datapower/datapower.conf
sed -i '$ a DataPowerLocalDir=/opt/ibm/datapower/local' /opt/ibm/datapower/datapower.conf
sed -i '$ a DataPowerAcceptLicense=true' /opt/ibm/datapower/datapower.conf
echo "==================================================="
echo "Restarting the DataPower service"
echo "==================================================="
systemctl restart datapower
echo "==================================================="
echo "Initial DataPower configuration"
echo "==================================================="
telnet 0 2200 <<EOF2

admin
admin

y
y
n
XXXXXXXXX
XXXXXXXXX
co
web-mgmt 0 9090 0
write m
y
exit
exit
EOF2
echo "Telnet ended"
EOF1

echo "==================================================="
log_title "DONE"
echo "==================================================="