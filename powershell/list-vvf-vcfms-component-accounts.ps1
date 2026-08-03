# VCF Operations Credentials
$VCFOperationsFQDN = "vcf03.vcf.lab"
$VCFOperationsAdminPassword = "VMware1!VMware1!"

##### DO NOT EDIT BEYOND HERE #####

# --- VCF Operations Authentication ---
$vcfOpsAuthParams = @{
    Uri = "https://${VCFOperationsFQDN}/suite-api/api/auth/token/acquire"
    Method = "POST"
    Headers = @{
        "Content-Type" = "application/json"
        "Accept" = "application/json"
    }
    Body = @{
        "username" = "admin"
        "password" = $VCFOperationsAdminPassword
        "authSource" = "local"
    } | ConvertTo-Json
    SkipCertificateCheck = $true
}

$vcfOpsAuthResponse = Invoke-WebRequest @vcfOpsAuthParams

$vcfOpsToken=$(($vcfOpsAuthResponse.Content | ConvertFrom-Json).token)

$headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
    "Authorization" = "OpsToken ${vcfOpsToken}"
    "X-Ops-API-use-unsupported" = "true"
}

$listIntegrationsParams = @{
    Uri                  = "https://${VCFOperationsFQDN}/suite-api/api/integrations/services"
    Method               = 'GET'
    Headers              = $headers
    SkipCertificateCheck = $true
}

$listIntegrationResponse = Invoke-WebRequest @listIntegrationsParams
$integrations = ($listIntegrationResponse.Content | ConvertFrom-Json).servicesDetails | where {$_.name -eq "VCF Services Platform"} | select name, key, address

foreach($integration in $integrations) {

    Write-Host "`n$($integration.name): $($integration.address) ($($integration.key))"

    $listCertificatesParams = @{
        Uri                  = "https://${VCFOperationsFQDN}/suite-api/api/integrations/services/password-management/$($integration.key)/accounts"
        Method               = 'GET'
        Headers              = $headers
        SkipCertificateCheck = $true
    }

    $request = Invoke-WebRequest @listCertificatesParams

        $accounts = ($request.Content | ConvertFrom-Json).accounts

        $accounts | Select-Object username,
        @{Name = 'passwordExpiryLocal'; Expression = {
                [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$_.passwordExpiry).LocalDateTime
        }},
        @{Name = 'passwordExpiryUtc'; Expression = {
                [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$_.passwordExpiry).UtcDateTime
        }} | Format-Table -AutoSize
}
