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

function Get-PemCertificateBlocks {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PemText
    )

    $pemPattern = '-----BEGIN CERTIFICATE-----\s*(?<Body>[A-Za-z0-9+/=\r\n\s]+?)\s*-----END CERTIFICATE-----'
    $matches = [System.Text.RegularExpressions.Regex]::Matches($PemText, $pemPattern)

    foreach ($match in $matches) {
        $base64Body = ($match.Groups['Body'].Value -replace '\s+', '')
        "-----BEGIN CERTIFICATE-----`n$base64Body`n-----END CERTIFICATE-----"
    }
}

function ConvertTo-CertificateSummary {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PemText,

        [Parameter(Mandatory = $true)]
        [string]$CertificateType,

        [Parameter(Mandatory = $true)]
        [string]$IngressType,

        [Parameter(Mandatory = $true)]
        [string[]]$ComponentFqdns,

        [Parameter(Mandatory = $true)]
        [string]$IntegrationName,

        [Parameter(Mandatory = $true)]
        [int]$ChainIndex
    )

    $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem($PemText)
    $subjectAlternativeName = $certificate.Extensions |
        Where-Object { $_.Oid.FriendlyName -eq 'Subject Alternative Name' } |
        ForEach-Object { $_.Format($true).Trim() }

    [PSCustomObject]@{
        IntegrationName        = $IntegrationName
        IngressType            = $IngressType
        ComponentFqdns         = ($ComponentFqdns -join ', ')
        CertificateType        = $CertificateType
        ChainIndex             = $ChainIndex
        Subject                = $certificate.Subject
        Issuer                 = $certificate.Issuer
        NotBefore              = $certificate.NotBefore
        NotAfter               = $certificate.NotAfter
        Thumbprint             = $certificate.Thumbprint
        SerialNumber           = $certificate.SerialNumber
        SignatureAlgorithm     = $certificate.SignatureAlgorithm.FriendlyName
        PublicKeyAlgorithm     = $certificate.PublicKey.Oid.FriendlyName
        KeySize                = $certificate.PublicKey.Key.KeySize
        SubjectAlternativeName = ($subjectAlternativeName -join '; ')
    }
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
        Uri                  = "https://${VCFOperationsFQDN}/suite-api/api/integrations/services/certificate-management/$($integration.key)/certificates"
        Method               = 'GET'
        Headers              = $headers
        SkipCertificateCheck = $true
    }

    $request = Invoke-WebRequest @listCertificatesParams
    $certificateResponse = $request.Content | ConvertFrom-Json

    foreach ($certificateEntry in $certificateResponse.certificates) {
        $chainSummaries = @(Get-PemCertificateBlocks -PemText $certificateEntry.tls.certificateChain | ForEach-Object -Begin { $chainIndex = 0 } -Process {
            ConvertTo-CertificateSummary `
                -PemText $_ `
                -CertificateType 'certificateChain' `
                -IngressType $certificateEntry.ingressType `
                -ComponentFqdns $certificateEntry.componentFqdns `
                -IntegrationName $integration.name `
                -ChainIndex $chainIndex

            $chainIndex++
        })

        $leafSummary = Get-PemCertificateBlocks -PemText $certificateEntry.tls.certificate |
            Select-Object -First 1 |
            ForEach-Object {
                ConvertTo-CertificateSummary `
                    -PemText $_ `
                    -CertificateType 'certificate' `
                    -IngressType $certificateEntry.ingressType `
                    -ComponentFqdns $certificateEntry.componentFqdns `
                    -IntegrationName $integration.name `
                    -ChainIndex 0
            }

        $chainSummaries + $leafSummary | Format-List
    }
}
