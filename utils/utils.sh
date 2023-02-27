#!/bin/bash
##################################################################################
CUR_DIR=$(dirname `readlink -f "${BASH_SOURCE[0]}" 2>/dev/null||echo $0`)
. $CUR_DIR/settings.conf
. $CUR_DIR/dp-rmi-utils.sh
. $CUR_DIR/dp-xmi-utils.sh
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
# Calculates number of dynamic objects
##################################################################################
numOfObjects(){
    OBJ=$1

    SEQ=0
    while [ true ]; do
        CUR_OBJ="$(getIndirectValue $OBJ $SEQ)"
        if [ -z "$CUR_OBJ" ]; then
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
declare -a NUM_OF_DPS="$(numOfObjects "DP_MGMT_IP_SERVER")"
for ((CUR_DP_SEQ=0; CUR_DP_SEQ<$NUM_OF_DPS; CUR_DP_SEQ++)); do
    CUR_HOST="$(getIndirectValue DP_MGMT_HOSTNAME_SERVER $CUR_DP_SEQ)"
    CUR_SOMA_PORT="$(getIndirectValue DP_SOMA_PORT_SERVER $CUR_DP_SEQ)"
    CUR_ROMA_PORT="$(getIndirectValue DP_ROMA_PORT_SERVER $CUR_DP_SEQ)"
    declare DP_SOMA_URL_SERVER$CUR_DP_SEQ="https://${CUR_HOST}:${CUR_SOMA_PORT}${DP_SOMA_URI}"
    declare DP_ROMA_URL_SERVER$CUR_DP_SEQ="https://${CUR_HOST}:${CUR_ROMA_PORT}"
done
##################################################################################
