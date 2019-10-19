#!/bin/bash

set -eu

export ROOT_DIR=`pwd`
source $ROOT_DIR/vops-suite-ci-pipeline/functions/vrops_functions.bash
####################################################
## waiting for vm to be ready
echo "Waiting for VM to Power On"
while [[ "$(curl -ski -o /dev/null -w ''%{http_code}'' https://$VROPS_IP/casa/node/thumbprint)" != "200" ]];
  do printf '.' sleep 10;
done
####################################################
## get vrops thumbprint
echo "Retrieving thumbprint"
VROPS_THUMBPRINT=$(getThumbprint)
echo ""
echo $VROPS_THUMBPRINT
echo ""
####################################################
## configure vrops cluster
configCluster
## monitor the cluster status
waitForClusterFinish
####################################################