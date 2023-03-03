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
log_title "Copying ssh key to the server"

scp $USER_SSH_PUBLIC_KEY $DP_LINUX_ROOT_USER_SERVER0@$DP_LINUX_SERVER0:~/.ssh/authorized_keys

echo "==================================================="
log_title "DONE"
echo "==================================================="
