#!/bin/bash
##################################################################################
# TBD
# 
##################################################################################
# Tested on DataPower firmware vesions:
#  TBD
##################################################################################

##################################################################################
# Main section
##################################################################################
exit
. ../utils/utils.sh

cd $PROJECT_DIR
echo =====================================================================================
declare -a NUM_OF_DPS="$(numOfDpGateways)"

for ((CUR_DP_SEQ=0; CUR_DP_SEQ<$NUM_OF_DPS; CUR_DP_SEQ++)); do
    CUR_DP_USERNAME="$(getIndirectValue DP_USER_NAME_SERVER $CUR_DP_SEQ)"
    CUR_DP_PASSWORD="$(getIndirectValue DP_USER_PASSWORD_SERVER $CUR_DP_SEQ)"
    CUR_DP_ROMA_URL="$(getIndirectValue DP_ROMA_URL_SERVER $CUR_DP_SEQ)"

done



