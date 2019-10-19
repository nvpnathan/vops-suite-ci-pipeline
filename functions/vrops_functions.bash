####################################################
# getThumbprint
getThumbprint() {
	responseCode=$(curl --write-out %{http_code} --output /dev/null -s -k -X GET https://$VROPS_IP/casa/node/thumbprint)
	if [ $responseCode -eq 200 ] ; then
		curl -s -k -X GET https://$VROPS_IP/casa/node/thumbprint
	else
		echo "Error: Unable to get thumbprint for '$VROPS_IP'"
		exit 1
	fi
}
####################################################
# configCluster
configCluster() {
	curl -ski -X POST \
		-H "Accept: application/json;charset=UTF-8" \
		-H "Content-Type: application/json;charset=UTF-8" \
		-d '{
                "master" : {
                "name" : "master-node",
                "address" : "'$VROPS_IP'",
                "thumbprint" : "'$VROPS_THUMBPRINT'"
                },
                "remoteCollector" : null,
                "admin_password" : "'$VROPS_PASS'",
                "ntp_servers" : [ "'$VROPS_NTP'" ],
                "init" : true,
                "dry-run" : false
                }' \
	'https://'$VROPS_IP'/casa/cluster'
}
####################################################
# getClusterStatus
getClusterStatus() {
	curl -sk -u $VROPS_USER:$VROPS_PASS -X GET https://$VROPS_IP/casa/cluster/status
}
####################################################
# Check cluster
checkClusterStatus() {
	clusterStatus=$(getClusterStatus)
	clusterState=$(echo $clusterStatus | jq .cluster_state | tr -d '"')
	nodesStates=$(echo $clusterStatus | jq .nodes_states[].state | tr -d '"' | uniq)
	if [ "$clusterState" == "INITIALIZED" ] && [ "$nodesStates" == "CONFIGURED" ]; then
		echo "Finished"
	fi
}
####################################################
# waitForClusterFinish
waitForClusterFinish() {
	echo ""
	echo "Info: Waiting until cluster configuration is finished..."
	local CYCLE=0
	local TIMEOUT_CYCLE=24
	local WAIT=300
	while true
	do
		STATUS=$(checkClusterStatus)
		if [ "$STATUS" == "Finished" ]; then
			echo "Info: Cluster has been configured"
			break
		else
			((++CYCLE))
			echo "Info: Waiting 5 minutes..."
			sleep $WAIT
		fi
		if [ $CYCLE -eq $TIMEOUT_CYCLE ]; then
			echo "Error: Not configured after 2 hours. Exiting..."
			exit 1
		fi
	done
}
####################################################
# Retrieve Bearer Token
getToken() {
    curl -ski -X POST \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    -d '{"username":"'$VROPS_USER'","authSource":"Local","password":"'$VROPS_PASS'"}' \
    'https://'$VROPS_IP'/suite-api/api/auth/token/acquire' \
    | sed -n 's|.*"token":"\([^"]*\)".*|\1|p'
}
####################################################
# Assign License
assignLicense() {
	curl -ski -X POST \
	-H 'Content-Type: application/json;charset=UTF-8' \
	-H 'Authorization: vRealizeOpsToken '$VROPS_BEARER_TOKEN'' \
	-d	'{
		"solutionLicenses" : [ {
			"id" : null,
			"licenseKey" : "'$VROPS_LICENSE'",
			"edition" : null,
			"others" : [ ],
			"otherAttributes" : { }
		} ]
		}' \
	'https://'$VROPS_IP'/suite-api/api/deployment/licenses'
}
####################################################
# Remove initial configuration wizard
removeWizard() {
	curl -ski -X POST \
	-H 'Content-Type: application/json;charset=UTF-8' \
	-H 'Authorization: vRealizeOpsToken '$VROPS_BEARER_TOKEN'' \
	-H 'X-vRealizeOps-API-use-unsupported: true' \
	-d	'{"keyValues": [ { "key": "configurationWizardFirstConfigDone", "values": ["true"] } ] }' \
	'https://'$VROPS_IP'/suite-api/internal/deployment/config/properties/java_util_HashSet'
}
####################################################
# Configure vCenter Adapter for Monitoring
configureVCadapter() {
	curl -ski -X POST \
	-H 'Content-Type: application/json;charset=UTF-8' \
	-H 'Authorization: vRealizeOpsToken '$VROPS_BEARER_TOKEN'' \
	-H 'Accept: application/json' \
	-d	'{
			"name" : "VC Adapter Instance",
			"description" : "A vCenter Adapter Instance",
			"collectorId" : "1",
			"adapterKindKey" : "VMWARE",
			"resourceIdentifiers" : [ {
				"name" : "AUTODISCOVERY",
				"value" : "true"
			}, {
				"name" : "PROCESSCHANGEEVENTS",
				"value" : "true"
			}, {
				"name" : "VCURL",
				"value" : "https://'$GOVC_URL'/sdk"
			} ],
			"credential" : {
				"id" : null,
				"name" : "New Principal Credential",
				"adapterKindKey" : "VMWARE",
				"credentialKindKey" : "PRINCIPALCREDENTIAL",
				"fields" : [ {
				"name" : "USER",
				"value" : "'$GOVC_USERNAME'"
				}, {
				"name" : "PASSWORD",
				"value" : "'$GOVC_PASSWORD'"
				} ],
				"others" : [ ],
				"otherAttributes" : {
				}
			},
			"others" : [ ],
			"otherAttributes" : {
			}
		}' \
	'https://'$VROPS_IP'/suite-api/api/adapters'
}
####################################################
# Get vCenter Adapter ID to start it
getVCadapterID() {
	curl -ski -X GET \
	-H 'Content-Type: application/json;charset=UTF-8' \
	-H 'Authorization: vRealizeOpsToken '$VROPS_BEARER_TOKEN'' \
	-H 'Accept: application/json' \
	'https://'$VROPS_IP'/suite-api/api/adapters?adapterKindKey=VMWARE' \
	| sed -n 's|.*"id":"\([^"]*\)".*|\1|p'
}
####################################################
# Start vCenter Adapter
startVCadapter() {
	curl -ski -X PUT \
	-H 'Content-Type: application/json;charset=UTF-8' \
	-H 'Authorization: vRealizeOpsToken '$VROPS_BEARER_TOKEN'' \
	-H 'Accept: application/json' \
	'https://'$VROPS_IP'/suite-api/api/adapters/'$VCADAPTER_ID'/monitoringstate/start'
}