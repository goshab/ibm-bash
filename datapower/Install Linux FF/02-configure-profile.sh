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
echo "Setting up shell profile"
echo "==================================================="
sed -i '$ a export HISTSIZE=5000' $SHELL_PROFILE_PATH
sed -i '$ a export HISTFILESIZE=2000' $SHELL_PROFILE_PATH
sed -i '$ a export KUBECONFIG=~/.kube/config' $SHELL_PROFILE_PATH
sed -i '$ a export TILLER_NAMESPACE=tiller' $SHELL_PROFILE_PATH
sed -i '$ a export PS1="\${debian_chroot:+(\$debian_chroot)}\\[\\033[01;32m\\]\\u@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\] $ "' $SHELL_PROFILE_PATH
sed -i '$ a alias ll="ls -lh"' $SHELL_PROFILE_PATH
sed -i '$ a alias size="du -hc --max-depth=0"' $SHELL_PROFILE_PATH
sed -i '$ a alias ic="ibmcloud"' $SHELL_PROFILE_PATH
sed -i '$ a alias k='kubectl'' $SHELL_PROFILE_PATH
sed -i '$ a unset TMOUT' $SHELL_PROFILE_PATH
cat $SHELL_PROFILE_PATH
EOF
log_title "DONE"
echo "==================================================="

# echo "==================================================="
# echo "Adding user"
# echo "==================================================="
# useradd -c "$DP_LINUX_USER_DESCRIPTION" $DP_LINUX_USER_NAME
# usermod -aG wheel $DP_LINUX_USER_NAME
# passwd $DP_LINUX_USER_NAME
# $DP_LINUX_USER_PASSWORD
# $DP_LINUX_USER_PASSWORD
# mkdir /home/$DP_LINUX_USER_NAME/.ssh/
# cp ~/.ssh/authorized_keys /home/$DP_LINUX_USER_NAME/.ssh/authorized_keys
# chown -R $DP_LINUX_USER_NAME:$DP_LINUX_USER_NAME /home/$DP_LINUX_USER_NAME/.ssh
# su $DP_LINUX_USER_NAME
