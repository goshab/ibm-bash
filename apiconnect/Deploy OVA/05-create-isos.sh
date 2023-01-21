#!/bin/bash
# ===========================================================================
if [ -z "$1" ]; then
    echo "Syntax:"
    echo "  Provide configuration filename as a parameter"
    exit
fi

if [ ! -f ./$1 ]; then
    echo "Configuration file $1 not found, aborting."
    exit
fi

# . ./00-env.conf
cd $PROJECT_DIR

echo "================================================================================"
echo "Generating ISO for Management service"
echo "================================================================================"
../../apicup subsys install mgmt --out mgmtplan-out
exit
echo "================================================================================"
echo "Generating ISO for Analytics service"
echo "================================================================================"
../../apicup subsys install analyt --out analytplan-out
echo "================================================================================"
echo "Generating ISO for Portal service"
echo "================================================================================"
../../apicup subsys install port --out portplan-out
echo "================================================================================"
