# Author: William Lam
# Description: Deploy VCF Operations 9.x OVA

$VCF_OPERATIONS_OVA = "Operations-Appliance-9.0.2.0.25137838.ova"

$VCENTER_HOST="vc01.vcf.lab"
$VCENTER_USERNAME="administrator@vsphere.local"
$VCENTER_PASSWORD="VMware1!VMware1!"
$VCENTER_CLUSTER="VCF-Mgmt-Cluster"
$VM_NETWORK="DVPG_FOR_VM_MANAGEMENT"
$VM_DATASTORE="vsanDatastore"

$VCF_OPERATIONS_VMNAME="vcf02"
$VCF_OPERATIONS_FQDN="vcf02.vcf.lab"
$VCF_OPERATIONS_DEPLOYMENT_SIZE="small"
$VCF_OPERATIONS_NETWORK_TYPE="Static"
$VCF_OPERATIONS_IP=172.30.0.100
$VCF_OPERATIONS_SUBNET=255.255.255.0
$VCF_OPERATIONS_GATEWAY=172.30.0.1
$VCF_OPERATIONS_DNS_SERVER=192.168.30.29
$VCF_OPERATIONS_DNS_DOMAIN="vcf.lab"
$VCF_OPERATIONS_DNS_SEARCH="vcf.lab"
$VCF_OPERATIONS_ROOT_PASSWORD="VMware1!VMware1!"
$VCF_OPERATIONS_TIMEZONE="Etc/UTC"
$VCF_OPERATIONS_ENABLE_SSH=$true
$VCF_OPERATIONS_ENABLE_FIPS=$true

#### DO NOT EDIT BEYOND HERE

if (-not $global:DefaultVIServer -or -not $global:DefaultVIServer.IsConnected) {
    Write-Error "No active PowerCLI connection found. Please run Connect-VIServer."
    exit
}

$ovfconfig = Get-OvfConfiguration $VCF_OPERATIONS_OVA
$ovfconfig.DeploymentOption.Value = $VCF_OPERATIONS_DEPLOYMENT_SIZE
$ovfconfig.Common.root_password.Value = $VCF_OPERATIONS_ROOT_PASSWORD
$ovfconfig.Common.enableFIPS.Value = $VCF_OPERATIONS_ENABLE_FIPS
$ovfconfig.Common.timezone.Value = $VCF_OPERATIONS_TIMEZONE
$ovfconfig.Common.VMware_Aria_Operations.domain.Value = $VCF_OPERATIONS_DNS_DOMAIN
$ovfconfig.Common.VMware_Aria_Operations.searchpath.Value = $VCF_OPERATIONS_DNS_SEARCH
$ovfconfig.Common.VMware_Aria_Operations.DNS.Value = $VCF_OPERATIONS_DNS_SERVER
$ovfconfig.Common.VMware_Aria_Operations.ipv4_type.Value = $VCF_OPERATIONS_NETWORK_TYPE
$ovfconfig.Common.VMware_Aria_Operations.ipv4_address.Value = $VCF_OPERATIONS_IP
$ovfconfig.Common.VMware_Aria_Operations.ipv4_gateway.Value = $VCF_OPERATIONS_GATEWAY
$ovfconfig.Common.VMware_Aria_Operations.ipv4_netmask.Value = $VCF_OPERATIONS_SUBNET
$ovfconfig.NetworkMapping.Network_1.Value = $VM_NETWORK

$VMHost = Get-Cluster $VCENTER_CLUSTER| Get-VMHost | Select -first 1

Write-Host -ForegroundColor Green  "Deploying VCF Operations ..."
$vm = Import-VApp -Source $VCF_OPERATIONS_OVA -OvfConfiguration $ovfconfig -Name $VCF_OPERATIONS_VMNAME -Location $VCENTER_CLUSTER -VMHost $VMHost -Datastore $VM_DATASTORE -DiskStorageFormat thin -Force

Write-Host -ForegroundColor Green "Powering on VCF Operations $VCF_OPERATIONS_VMNAME ..."
$vm | Start-VM -Confirm:$false | Out-Null

Write-Host "Waiting for VCF Operations UI to be ready ..."
while(1) {
    try {
        $requests = Invoke-WebRequest -Uri "https://${VCF_OPERATIONS_FQDN}/admin" -Method GET -SkipCertificateCheck -TimeoutSec 5
        if($requests.StatusCode -eq 200) {
            Write-Host "`tVCF Operations UI https://${VCF_OPERATIONS_FQDN}/admin is now ready!"
            break
        }
    }
    catch {
        Write-Host "VCF Operations UI is not ready yet, sleeping for 120 seconds ..."
        sleep 120
    }
}