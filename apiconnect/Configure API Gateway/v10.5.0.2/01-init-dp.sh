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
. ../../../utils/utils.sh

log_title "Creating the project folders"
mkidr $PROJECT_DIR
# cd $PROJECT_DIR

mkdir $PROJECT_DIR/$KEYS_DIR
# cd $KEYS_DIR
log_info "Please copy over the certificates and the private key to the $PROJECT_DIR/$KEYS_DIR folder"