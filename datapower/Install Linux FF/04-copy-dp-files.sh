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

echo "==================================================="
log_title "Configuring the target Linux environment"

if [ ! -z "$DP_BASE_IMAGE_PATH" ]; then
    echo "==================================================="
    log_title "Copying DataPower images to the Linux server"
    scp -C $DP_BASE_IMAGE_PATH -i $USER_SSH_PRIVATE_KEY $DP_LINUX_ROOT_USER_SERVER0@$DP_LINUX_SERVER0:/tmp/
fi

echo "==================================================="
log_title "Connecting to $DP_LINUX_SERVER0"
ssh -l $DP_LINUX_ROOT_USER_SERVER0 -i $USER_SSH_PRIVATE_KEY $DP_LINUX_SERVER0 <<EOF
echo "==================================================="
echo "Installing schroot"
echo "==================================================="
wget -P /tmp $SCHROOT_PACKAGE
yum -y install /tmp/schroot-1.6.10-10.el8.x86_64.rpm
echo "==================================================="
echo "Extracting DataPower packages"
echo "==================================================="
cd /tmp
chmod 777 $DP_IMAGE_FILENAME
tar -xvf $DP_IMAGE_FILENAME
chmod 777 *
EOF

echo "==================================================="
log_title "DONE"
echo "==================================================="