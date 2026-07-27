$IDB_FQDN="vcf-idb01.vcf.lab"
$IDB_API_TOKEN="FILL_ME_IN"
$VCENTER_SERVER_FQDN="vc01.vcf.lab"

#### DO NOT EDIT BEYOND HERE ####

$headers = @{
    'Content-Type' = 'application/x-www-form-urlencoded'
}

$body = @{
    grant_type = 'urn:custom:vcf:params:oauth:grant-type:api-token'
    api_token  = $IDB_API_TOKEN
}

# Step 1: Exchange IDB API Token for IDB Access Token
$requests = Invoke-RestMethod -Method Post -Uri "https://${IDB_FQDN}/acs/t/CUSTOMER/token" -Headers $headers -Body $body -SkipCertificateCheck
$accessToken = $requests.access_token

# Step 2: Exchange IDB Access Token for vCenter Server SAML Token
$vcHeaders = @{
    'Authorization' = "Bearer $accessToken"
    'Content-Type'  = 'application/x-www-form-urlencoded'
}

$vcBody = @{
    grant_type           = 'urn:ietf:params:oauth:grant-type:token-exchange'
    requested_token_type = 'urn:ietf:params:oauth:token-type:saml2'
    subject_token_type   = 'urn:ietf:params:oauth:token-type:access_token'
    subject_token        = $accessToken
}

$vcResponse = Invoke-WebRequest -Method Post -Uri "https://${VCENTER_SERVER_FQDN}/api/vcenter/authentication/token" -Headers $vcHeaders -Body $vcBody -SkipCertificateCheck
$samlToken = ($vcResponse.Content | ConvertFrom-Json).access_token

# Decode Base64 SAML token
$decodedSamlToken = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($samlToken))

# Compress the decoded SAML token
$compressedSamlToken = New-Object System.IO.MemoryStream
$gzipStream = New-Object System.IO.Compression.GZipStream($compressedSamlToken, [System.IO.Compression.CompressionMode]::Compress)
$gzipStream.Write([System.Text.Encoding]::UTF8.GetBytes($decodedSamlToken), 0, $decodedSamlToken.Length)
$gzipStream.Close()

# Base64 encode the compressed token
$encodedSamlToken = [System.Convert]::ToBase64String($compressedSamlToken.ToArray())

# Use SAML token to authenticate to vCenter Session API
$sessionHeaders = @{
    'Authorization' = "SIGN token=`"$encodedSamlToken`""
}

# Step 3: Login to vCenter Server using SAML token
$sessionResponse = Invoke-WebRequest -Method Post -Uri "https://${VCENTER_SERVER_FQDN}/api/session" -Headers $sessionHeaders -SkipCertificateCheck
if($sessionResponse.StatusCode -eq 201) {
    $vCenterSession = $sessionResponse.Content.Replace('"','')

    $vcenterHeaders = @{
        "vmware-api-session-id" = ${vCenterSession}
    }

    # Lists ESX hosts in vCenter Server
    $vCenterResponse = Invoke-WebRequest -Method GET -Uri "https://${VCENTER_SERVER_FQDN}/api/vcenter/host" -Headers $vcenterHeaders -SkipCertificateCheck
    if($vCenterResponse.StatusCode -eq 200) {
        $vCenterResponse.Content | ConvertFrom-Json
    }
}