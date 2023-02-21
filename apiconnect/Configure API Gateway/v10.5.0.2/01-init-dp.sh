#!/bin/bash
##################################################################################
. 99-utils.sh

if [ -z "$1" ]; then
    log_error "Syntax:"
    log_error "  Provide configuration filename as a parameter"
    exit
fi

if [ ! -f ./$1 ]; then
    log_error "Configuration file $1 not found, aborting."
    exit
fi

. $1

log_title "Creating the project folders"
mkidr $PROJECT_DIR
cd $PROJECT_DIR

mkdir $KEYS_DIR
cd $KEYS_DIR
log_info "Please copy over the certificates and the private key to the $PROJECT_DIR/$KEYS_DIR folder"