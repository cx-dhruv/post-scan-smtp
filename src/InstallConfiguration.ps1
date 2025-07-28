Import-Module "$PSScriptRoot\..\config\SecureConfig.psm1" -Force
$cfgPath = "$PSScriptRoot\..\config\config.sample.json"
$config   = Get-Content -Raw -Path $cfgPath | ConvertFrom-Json

Write-Host "`n=== SMTP Settings ==="
$useDefaultSmtp = Read-Host "Use default SMTP settings? (y/n)"
if ($useDefaultSmtp -eq 'y') {
    # Preconfigured SMTP settings for outlook.com
    $config.smtp.server = "smtp.office365.com"
    $config.smtp.port   = 587
    Set-SecureSecret "smtp-username" (Read-Host "Outlook SMTP username")
    Set-SecureSecret "smtp-password" (Read-Host "Outlook SMTP password" -AsSecureString | ConvertFrom-SecureString)
} else {
    $config.smtp.server = Read-Host "SMTP server address"
    $config.smtp.port   = [int](Read-Host "SMTP server port")
    Set-SecureSecret "smtp-username" (Read-Host "SMTP username")
    Set-SecureSecret "smtp-password" (Read-Host "SMTP password" -AsSecureString | ConvertFrom-SecureString)
}

Write-Host "`n=== Checkmarx Credentials ==="
$config.cxOne.region  = Read-Host "Region code (ind/eu/eu-2/na/us-2/anz/sng/mea...)" -Default $config.cxOne.region
$config.cxOne.tenant  = Read-Host "Tenant name" -Default $config.cxOne.tenant
Set-SecureSecret "$($config.cxOne.tenant)-clientId"     (Read-Host "Client ID")
Set-SecureSecret "$($config.cxOne.tenant)-clientSecret" (Read-Host "Client Secret")

$config | ConvertTo-Json -Depth 5 | Out-File "$PSScriptRoot\..\config\config.json" -Encoding utf8

Write-Host "Enter recipient addresses (comma-separated): "
(Read-Host) -split ',' | Out-File "$PSScriptRoot\..\config\recipients.txt" -Encoding utf8
