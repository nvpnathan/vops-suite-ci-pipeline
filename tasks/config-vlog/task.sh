#!/bin/bash

set -eu

export ROOT_DIR=`pwd`
source $ROOT_DIR/vops-suite-ci-pipeline/functions/li_functions.bash

LISESSIONID=""

echo "Waiting for VM to Power On"
while [[ "$(curl -ski -o /dev/null -w ''%{http_code}'' https://$VLOG_IP/admin/startup)" != "200" ]];
  do printf '.' sleep 10;
done

echo "Configure New Deployment"
liapi $VLOG_IP POST deployment/new '{"user": {"userName": "'"$VLOG_USER"'", "password": "'"$VLOG_PASS"'", "email": "'"$VLOG_EMAIL"'"}}'

while [[ "$(curl -ski -X POST -o /dev/null -w ''%{http_code}'' https://$VLOG_IP:9543/api/v1/deployment/waitUntilStarted)" != "200" ]];
  do printf '.' sleep 10;
done

echo "Finished Configuring Deployment"
## Get LISESSIONID
liauth $VLOG_IP Local $VLOG_USER $VLOG_PASS

echo "Assign license"
curl -ki -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer "'$LISESSIONID'"' '-d {"key":"'$VLOG_LICENSE'"}' \
https://$VLOG_IP:9543/api/v1/licenses

echo
echo "Finished Configuring Log Insight"