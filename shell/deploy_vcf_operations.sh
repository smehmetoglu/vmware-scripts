#!/bin/bash
# Author: William Lam
# Description: Deploy VCF Operations 9.x OVA

OVFTOOL="/usr/bin/ovftool"
VCF_OPERATIONS_OVA="Operations-Appliance-9.0.2.0.25137838.ova"

VCENTER_HOST="vc01.vcf.lab"
VCENTER_USERNAME="administrator@vsphere.local"
VCENTER_PASSWORD="VMware1!VMware1!"
VCENTER_DATACENTER="VCF-Datacenter"
VCENTER_CLUSTER="VCF-Mgmt-Cluster"
VM_NETWORK="DVPG_FOR_VM_MANAGEMENT"
VM_DATASTORE="vsanDatastore"

VCF_OPERATIONS_VMNAME="vcf02"
VCF_OPERATIONS_FQDN="vcf02.vcf.lab"
VCF_OPERATIONS_DEPLOYMENT_SIZE="small"
VCF_OPERATIONS_NETWORK_TYPE="Static"
VCF_OPERATIONS_IP="172.30.0.100"
VCF_OPERATIONS_SUBNET="255.255.255.0"
VCF_OPERATIONS_GATEWAY="172.30.0.1"
VCF_OPERATIONS_DNS_SERVER="192.168.30.29"
VCF_OPERATIONS_DNS_DOMAIN="vcf.lab"
VCF_OPERATIONS_DNS_SEARCH="vcf.lab"
VCF_OPERATIONS_ROOT_PASSWORD="VMware1!VMware1!"
VCF_OPERATIONS_TIMEZONE="Etc/UTC"
VCF_OPERATIONS_ENABLE_SSH="True"
VCF_OPERATIONS_ENABLE_FIPS="True"

### DO NOT EDIT BEYOND HERE ###

echo -e "\nDeploying VCF Operation ${VCF_OPERATIONS_VMNAME} ..."
"${OVFTOOL}" --acceptAllEulas --noSSLVerify --skipManifestCheck --X:enableHiddenProperties --allowExtraConfig --X:waitForIp --sourceType=OVA --powerOn \
"--deploymentOption=${VCF_OPERATIONS_DEPLOYMENT_SIZE}" \
"--net:Network 1=${VM_NETWORK}" --datastore=${VM_DATASTORE} --diskMode=thin --name=${VCF_OPERATIONS_VMNAME} \
"--prop:ipv4_type.VMware_Aria_Operations=${VCF_OPERATIONS_NETWORK_TYPE}" \
"--prop:ipv4_address.VMware_Aria_Operations=${VCF_OPERATIONS_IP}" \
"--prop:ipv4_netmask.VMware_Aria_Operations=${VCF_OPERATIONS_SUBNET}" \
"--prop:ipv4_gateway.VMware_Aria_Operations=${VCF_OPERATIONS_GATEWAY}" \
"--prop:domain.VMware_Aria_Operations=${VCF_OPERATIONS_DNS_DOMAIN}" \
"--prop:searchpath.VMware_Aria_Operations=${VCF_OPERATIONS_DNS_SEARCH}" \
"--prop:DNS.VMware_Aria_Operations=${VCF_OPERATIONS_DNS_SERVER}" \
"--prop:enableFIPS=${VCF_OPERATIONS_ENABLE_FIPS}" \
"--prop:timezone=${VCF_OPERATIONS_TIMEZONE}" \
"--prop:guestinfo.cis.appliance.ssh.enabled=${VCF_OPERATIONS_ENABLE_SSH}" \
"--prop:root_password=${VCF_OPERATIONS_ROOT_PASSWORD}" \
${VCF_OPERATIONS_OVA} "vi://${VCENTER_USERNAME}:${VCENTER_PASSWORD}@${VCENTER_HOST}/${VCENTER_DATACENTER}/host/${VCENTER_CLUSTER}"

echo "Waiting for VCF Operations UI to be ready ..."

while true; do
    STATUS=$(curl -sk -o /dev/null -w "%{http_code}" "https://${VCF_OPERATIONS_FQDN}/admin" --connect-timeout 5)

    if [ "$STATUS" -eq 200 ]; then
        echo -e "\tVCF Operations UI https://${VCF_OPERATIONS_FQDN}/admin is now ready!"
        break
    else
        echo "VCF Operations UI is not ready yet (Status: $STATUS), sleeping for 120 seconds ..."
        sleep 120
    fi
done