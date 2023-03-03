#!/bin/bash
##################################################################################
# Usage
#   Run only once.
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
log_title "Configuring the target Linux OS environment"

echo "==================================================="
log_title "Connecting to $DP_LINUX_SERVER0"
ssh -l $DP_LINUX_ROOT_USER_SERVER0 -i $USER_SSH_PRIVATE_KEY $DP_LINUX_SERVER0 <<EOF
echo "Connected to \$(hostname) using \$(whoami)"
echo "==================================================="
echo "Disabling local firewalld"
echo "==================================================="
systemctl disable firewalld
systemctl status firewalld
echo "==================================================="
echo "Installing telnet"
echo "==================================================="
yum -y install telnet
echo "==================================================="
echo "Installing net-tools"
echo "==================================================="
yum -y install net-tools
echo "==================================================="
echo "Installing httpd-tools"
echo "==================================================="
yum -y install httpd-tools
echo "==================================================="
EOF
log_title "DONE"
echo "==================================================="