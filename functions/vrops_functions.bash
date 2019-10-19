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
	responseConfigCode=$(curl -ski -X POST \
		--write-out %{http_code} --output /dev/null \
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
	'https://'$VROPS_IP'/casa/cluster')
	if [ $responseConfigCode -eq 500 ] ; then
		echo $responseConfigCode
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