Function Get-Vcf9ComponentBundleName {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet(
            "9.0.0.0", "9.0.1.0"
        )]
        [string]$Version,

        [Parameter(Mandatory=$true)][string]$BroadcomDownloadToken
    )

    $pvcUrl = "https://dl.broadcom.com/${BroadcomDownloadToken}/PROD/metadata/productVersionCatalog/v1/productVersionCatalog.json"

    $patches = ((Invoke-WebRequest -Uri $pvcUrl | ConvertFrom-Json).patches)

    $results = @()
    foreach ($componentName in ($patches | Get-Member -MemberType NoteProperty).Name) {
        $components = ${patches}.${componentName}
        foreach ($component in $components) {
            if($component.productVersion -match $Version) {
                $bundles = $component.artifacts.bundles

                foreach ($bundle in $bundles) {
                    $tmp = [pscustomobject] @{
                        Name = $componentName
                        Version = $component.productVersion
                        Type = $bundle.type
                        BundleID = $bundle.name
                        FileName = $bundle.binaries.filename
                    }
                    $results+=$tmp
                }
            }
        }
    }

    $results | Sort-Object -Property Name | ft
}

Function Get-Vcf345ComponentBundleName {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet(
            "3.10.1.1", "3.10.1.2", "3.10.2.0", "3.10.2.1", "3.10.2.2",
            "3.11.0.0", "3.11.0.1", "4.0.0.0", "4.0.0.1", "4.0.1.0",
            "4.0.1.1", "4.1.0.0", "4.1.0.1", "4.2.0.0", "4.2.1.0",
            "4.3.0.0", "4.3.1.0", "4.3.1.1", "4.4.0.0", "4.4.1.0",
            "4.4.1.1", "4.5.0.0", "4.5.1.0", "4.5.2.0", "5.0.0.0",
            "5.0.0.1", "5.1.0.0", "5.1.1.0", "5.2.0.0", "5.2.1.0",
            "5.2.2.0"
        )]
        [string]$Version,

        [Parameter(Mandatory=$true)][string]$BroadcomDownloadToken
    )

    $lcmManifestUrl = "https://dl.broadcom.com/${BroadcomDownloadToken}/PROD/COMP/SDDC_MANAGER_VCF/lcm/manifest/v1/lcmManifest.json"
    $indexUrl = "https://dl.broadcom.com/${BroadcomDownloadToken}/PROD/COMP/SDDC_MANAGER_VCF/index.v3"

    $release = ((Invoke-WebRequest -Uri $lcmManifestUrl | ConvertFrom-Json).releases | where {$_.version -eq ${Version}})
    $bom = $release.bom
    $patches = $release.patchBundles

    $indexConnect = (Invoke-WebRequest -Uri $indexUrl).RawContent

    $results = @()
    foreach ($patch in $patches) {
        $componentName = $patch.bundleElements[0]
        $bundleVersion = ($bom | where {$_.name -eq $patch[0].bundleElements[0]}).version

        $lines = $indexConnect -split "`n" | Where-Object { $_ -match $patch.bundleId }
        $bundleId = ($lines.Trim() -split '\s+')[1] -replace '\.manifest$', ''

        $tmp = [pscustomobject] @{
            Name = $componentName
            Version = $bundleVersion
            BundleID = $bundleId
            Id = $patch.bundleId
        }
        $results+=$tmp
    }

    $results | Sort-Object -Property Name | ft
}