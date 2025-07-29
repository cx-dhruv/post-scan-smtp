Import-Module "$PSScriptRoot\..\config\SecureConfig.psm1" -Force
$cfgPath = "$PSScriptRoot\..\config\config.sample.json"
$config   = Get-Content -Raw -Path $cfgPath | ConvertFrom-Json

Write-Host "`n=== SMTP Settings ==="
$useDefaultSmtp = Read-Host "Use default SMTP settings? (y/n)"
if ($useDefaultSmtp -eq 'y') {
    # Preconfigured SMTP settings for Gmail
    $config.smtp.server = "smtp.gmail.com"
    $config.smtp.port   = 587
    $config.smtp.username = $config.smtp.username
    $config.smtp.password = $config.smtp.password
} else {
    $config.smtp.server = Read-Host "SMTP server address"
    $config.smtp.port   = [int](Read-Host "SMTP server port")
    $config.smtp.username = Read-Host "SMTP username"
    $config.smtp.password = Read-Host "SMTP password" -AsSecureString | ConvertFrom-SecureString
}

Set-SecureSecret "smtp-username" $config.smtp.username
Set-SecureSecret "smtp-password" $config.smtp.password

Write-Host "`n=== Checkmarx Credentials ==="
$config.cxOne.region  = Read-Host "Region code (ind/eu/eu-2/na/us-2/anz/sng/mea...)" -Default $config.cxOne.region
$config.cxOne.tenant  = Read-Host "Tenant name" -Default $config.cxOne.tenant
Set-SecureSecret "$($config.cxOne.tenant)-clientId"     (Read-Host "Client ID")
Set-SecureSecret "$($config.cxOne.tenant)-clientSecret" (Read-Host "Client Secret")

$config | ConvertTo-Json -Depth 5 | Out-File "$PSScriptRoot\..\config\config.json" -Encoding utf8

Write-Host "Enter recipient addresses (comma-separated): "
(Read-Host) -split ',' | Out-File "$PSScriptRoot\..\config\recipients.txt" -Encoding utf8
