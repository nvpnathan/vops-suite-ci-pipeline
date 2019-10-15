#!/bin/bash

set -eu

export OVA_ISO_PATH='./vrops-ova'

file_path=$(find $OVA_ISO_PATH/ -name "*.ova")

echo "$file_path"

if echo $GOVC_INSECURE == "1"
  then echo "Insecure vCenter Cert"
else
  export GOVC_TLS_CA_CERTS=/tmp/vcenter-ca.pem
  echo "$GOVC_CA_CERT" > "$GOVC_TLS_CA_CERTS"
fi

govc import.spec "$file_path" | python -m json.tool > vrops-import.json

cat > filters <<'EOF'
.Deployment = $vmSize |
.Name = $vmName |
.DiskProvisioning = $diskType |
.NetworkMapping[].Network = $network |
.PowerOn = $powerOn |
.IPAllocationPolicy = $ipallocation |
(.PropertyMapping[] | select(.Key == "vami.ip0.vRealize_Operations_Manager_Appliance")).Value = $ip0 |
(.PropertyMapping[] | select(.Key == "vami.netmask0.vRealize_Operations_Manager_Appliance")).Value = $netmask0 |
(.PropertyMapping[] | select(.Key == "vami.gateway.vRealize_Operations_Manager_Appliance")).Value = $gateway |
(.PropertyMapping[] | select(.Key == "vami.DNS.vRealize_Operations_Manager_Appliance")).Value = $dns |
(.PropertyMapping[] | select(.Key == "vami.searchpath.vRealize_Operations_Manager_Appliance")).Value = $dnsSearch |
(.PropertyMapping[] | select(.Key == "vami.domain.vRealize_Operations_Manager_Appliance")).Value = $dnsDomain
EOF

jq \
  --arg vmSize "$VROPS_DEPLOYMENT_SIZE" \
  --arg ipallocation "$VROPS_IP_POLICY" \
  --arg ip0 "$VROPS_IP" \
  --arg netmask0 "$VROPS_NETMASK" \
  --arg gateway "$VROPS_GATEWAY" \
  --arg dns "$VROPS_DNS_SERVER" \
  --arg dnsSearch "$VROPS_SEARCH_PATH" \
  --arg dnsDomain "$VROPS_DOMAIN_NAME" \
  --arg network "$VROPS_PORTGROUP" \
  --arg vmName "$VROPS_NAME" \
  --arg diskType "$VROPS_DISK_PROVISION" \
  --argjson powerOn "$VROPS_POWER_ON" \
  --from-file filters \
  vrops-import.json > options.json

cat options.json

if [ -z "$VROPS_VM_FOLDER" ]; then
  govc import.ova -options=options.json "$file_path"
else
  if [ "$(govc folder.info "$VROPS_VM_FOLDER" 2>&1 | grep "$VROPS_VM_FOLDER" | awk '{print $2}')" != "$VROPS_VM_FOLDER" ]; then
    govc folder.create "$VROPS_VM_FOLDER"
  fi
  govc import.ova -folder="$VROPS_VM_FOLDER" -options=options.json "$file_path"
fi