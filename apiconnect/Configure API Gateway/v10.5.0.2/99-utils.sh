#!/bin/bash

##################################################################################
# log
##################################################################################
log_success() {
    MSG=$1

    echo -e $GREEN"$MSG"$NC
}
##################################################################################
# log
##################################################################################
log_error() {
    MSG=$1

    echo -e $RED"$MSG"$NC
}
##################################################################################
# log
##################################################################################
log_info() {
    MSG=$1

    echo -e $PURPLE"$MSG"$NC
}
##################################################################################
# log
##################################################################################
log_title() {
    MSG=$1

    echo -e $BLUE"$MSG"$NC
}
##################################################################################
# Calculates number of DP servers
##################################################################################
numOfDpGateways(){
    SEQ=1

    while [ true ]; do
        CUR_DP="$(getIndirectValue DP_MGMT_IP_SERVER $SEQ)"
        if [ -z "$CUR_DP" ]; then
            echo $SEQ
            exit
        fi
        ((SEQ++))
    done
}
##################################################################################
# Get indirect variable value
##################################################################################
getIndirectValue(){
    PREFIX=$1
    SUFFIX=$2

    result="$PREFIX${SUFFIX}"
    result="${!result}"
    echo $result
}
##################################################################################
