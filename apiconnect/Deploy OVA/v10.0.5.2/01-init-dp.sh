#!/bin/bash
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

mkidr $PROJECT_DIR
cd $PROJECT_DIR

mkdir $KEYS_DIR
cd $KEYS_DIR
