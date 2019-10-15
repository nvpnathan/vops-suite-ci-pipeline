#!/bin/bash

set -eu

export ROOT_DIR=`pwd`
export VMWFILESDIR=$ROOT_DIR/vlog-ova/rootfs/
export PATH=$ROOT_DIR/vlog-ova/rootfs/usr/local/bin:$PATH

vmw-cli index $VLOG_INDEX

if [ -f "$VMWFILESDIR/$VLOG_OVA" ]; then
    echo "$VLOG_OVA exists"
    export OVA_ISO_PATH=$VMWFILESDIR
else 
    echo "$VLOG_OVA does not exist downloading"
    vmw-cli get $VLOG_OVA
    export OVA_ISO_PATH=$VMWFILESDIR
fi

file_path=$(find $OVA_ISO_PATH/ -name "*.ova")

echo "$file_path"

if echo $GOVC_INSECURE == "1"
  then echo "Insecure vCenter Cert"
else
  export GOVC_TLS_CA_CERTS=/tmp/vcenter-ca.pem
  echo "$GOVC_CA_CERT" > "$GOVC_TLS_CA_CERTS"
fi

govc import.spec "$file_path" | python -m json.tool > vlog-import.json

cat > filters <<'EOF'
.Deployment = $vmSize |
.Name = $vmName |
.DiskProvisioning = $diskType |
.NetworkMapping[].Network = $network |
.PowerOn = $powerOn |
.IPAllocationPolicy = $ipallocation |
(.PropertyMapping[] | select(.Key == "vami.hostname.VMware_vCenter_Log_Insight")).Value = $hostname |
(.PropertyMapping[] | select(.Key == "vami.ip0.VMware_vCenter_Log_Insight")).Value = $ip0 |
(.PropertyMapping[] | select(.Key == "vami.netmask0.VMware_vCenter_Log_Insight")).Value = $netmask0 |
(.PropertyMapping[] | select(.Key == "vami.gateway.VMware_vCenter_Log_Insight")).Value = $gateway |
(.PropertyMapping[] | select(.Key == "vami.DNS.VMware_vCenter_Log_Insight")).Value = $dns |
(.PropertyMapping[] | select(.Key == "vami.searchpath.VMware_vCenter_Log_Insight")).Value = $dnsSearch |
(.PropertyMapping[] | select(.Key == "vami.domain.VMware_vCenter_Log_Insight")).Value = $dnsDomain |
(.PropertyMapping[] | select(.Key == "vm.rootpw")).Value = $rootPW
EOF

jq \
  --arg vmSize "$VLOG_DEPLOYMENT_SIZE" \
  --arg ipallocation "$VLOG_IP_POLICY" \
  --arg hostname "$VLOG_NAME" \
  --arg ip0 "$VLOG_IP" \
  --arg netmask0 "$VLOG_NETMASK" \
  --arg gateway "$VLOG_GATEWAY" \
  --arg dns "$VLOG_DNS_SERVER" \
  --arg dnsSearch "$VLOG_SEARCH_PATH" \
  --arg dnsDomain "$VLOG_DOMAIN_NAME" \
  --arg network "$VLOG_PORTGROUP" \
  --arg vmName "$VLOG_VM_NAME" \
  --arg diskType "$VLOG_DISK_PROVISION" \
  --arg rootPW "$VLOG_ROOT_PW" \
  --argjson powerOn "$VLOG_POWER_ON" \
  --from-file filters \
  vlog-import.json > options.json

cat options.json

if [ -z "$VLOG_VM_FOLDER" ]; then
  govc import.ova -options=options.json "$file_path"
else
  if [ "$(govc folder.info "$VLOG_VM_FOLDER" 2>&1 | grep "$VLOG_VM_FOLDER" | awk '{print $2}')" != "$VLOG_VM_FOLDER" ]; then
    govc folder.create "$VLOG_VM_FOLDER"
  fi
  govc import.ova -folder="$VLOG_VM_FOLDER" -options=options.json "$file_path"
fi