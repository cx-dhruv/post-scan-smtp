# InstallConfiguration.ps1
# Initial setup wizard for CxMailer credentials and settings
# Must be run as Administrator to ensure SYSTEM account can access credentials

Import-Module "$PSScriptRoot\..\config\SecureConfig.psm1" -Force -DisableNameChecking

$configPath = "$PSScriptRoot\..\config\config.json"
$sampleConfigPath = "$PSScriptRoot\..\config\config.sample.json"
$envPath = "$PSScriptRoot\..\config\.env"

# === INITIALIZATION PROCESS FOR NEW SYSTEM DEPLOYMENT ===
# 1. This script creates the initial configuration structure
# 2. Prompts for all required credentials (SMTP and Checkmarx API)
# 3. Stores credentials encrypted using Windows DPAPI with machine-level protection
# 4. Creates config.json with non-sensitive settings
# 5. Sets up email recipient list in recipients.txt
# 
# IMPORTANT: Must run as Administrator so SYSTEM account can decrypt credentials
# The encryption uses machine-specific keys from HKLM registry

# Load existing config or use sample as template
if (Test-Path $configPath -PathType Leaf) {
    try {
        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Host "⚠ config.json is invalid. Using sample config."
        $config = $null
    }
}
if (-not $config -and (Test-Path $sampleConfigPath -PathType Leaf)) {
    # WARNING: Sample config should NOT contain real credentials
    $config = Get-Content -Raw -Path $sampleConfigPath | ConvertFrom-Json
}

# If still null, create empty config
if (-not $config) {
    $config = [PSCustomObject]@{}
}

# Guarantee smtp object exists
if (-not $config.smtp) {
    $config | Add-Member -MemberType NoteProperty -Name smtp -Value ([PSCustomObject]@{
            server   = ""
            port     = 0
            username = ""
            password = ""
            from     = ""
        })
}

# Guarantee cxOne object exists
if (-not $config.cxOne) {
    $config | Add-Member -MemberType NoteProperty -Name cxOne -Value ([PSCustomObject]@{
            region = ""
            tenant = ""
        })
}

# Load .env if present
if (Test-Path $envPath) {
    Use-EnvFile $envPath
}
else {
    Write-Host "No .env found at $envPath, proceeding with prompts."
}

Write-Host "`n=== SMTP Settings ==="
Write-Host "Enter SMTP server configuration for sending notification emails"
$useDefaultSmtp = Read-Host "Use default SMTP settings? (y/n)"
if ($useDefaultSmtp -eq 'y') {
    # Load from environment variables if available (development convenience)
    $config.smtp.server = [System.Environment]::GetEnvironmentVariable("SERVER")
    $config.smtp.port = [System.Environment]::GetEnvironmentVariable("PORT")
    $config.smtp.username = [System.Environment]::GetEnvironmentVariable("USERNAME")
    $config.smtp.password = [System.Environment]::GetEnvironmentVariable("PASSWORD")
}
else {
    # Prompt for SMTP configuration
    $config.smtp.server = Read-Host "SMTP server address"
    $config.smtp.port = [int](Read-Host "SMTP server port")
    $config.smtp.username = Read-Host "SMTP username"
    $config.smtp.password = Read-Host "SMTP password"
}

# Store SMTP credentials securely
# These are encrypted and can only be decrypted on this machine
if (-not [string]::IsNullOrWhiteSpace($config.smtp.username)) {
    Set-SecureSecret "smtp-username" $config.smtp.username
}
else {
    Write-Host "SMTP username is missing."
}

if (-not [string]::IsNullOrWhiteSpace($config.smtp.password)) {
    Set-SecureSecret "smtp-password" $config.smtp.password
}
else {
    Write-Host "SMTP password is missing."
}

if (-not [string]::IsNullOrWhiteSpace($config.smtp.server)) {
    Set-SecureSecret "smtp-server" $config.smtp.server
} else {
    Write-Host "SMTP server is missing. Please configure it."
    throw "SMTP server is missing."
}

Write-Host "`n=== Checkmarx Credentials ==="
Write-Host "Enter Checkmarx ONE API credentials (OAuth2 client credentials flow)"
$regionFromEnv = [System.Environment]::GetEnvironmentVariable("CX_REGION")
if (-not [string]::IsNullOrWhiteSpace($regionFromEnv)) { $config.cxOne.region = $regionFromEnv }

$tenantFromEnv = [System.Environment]::GetEnvironmentVariable("CX_TENANT")
if (-not [string]::IsNullOrWhiteSpace($tenantFromEnv)) { $config.cxOne.tenant = $tenantFromEnv }

$clientIdFromEnv = [System.Environment]::GetEnvironmentVariable("CX_CLIENT_ID")
$clientSecretFromEnv = [System.Environment]::GetEnvironmentVariable("CX_CLIENT_SECRET")

# Store Checkmarx API credentials with tenant-specific keys
# This allows multiple tenant support if needed
if (-not [string]::IsNullOrWhiteSpace($clientIdFromEnv)) {
    Set-SecureSecret "$($config.cxOne.tenant)-clientId" $clientIdFromEnv
}
else {
    Set-SecureSecret "$($config.cxOne.tenant)-clientId" (Read-Host "Client ID")
}

if (-not [string]::IsNullOrWhiteSpace($clientSecretFromEnv)) {
    Set-SecureSecret "$($config.cxOne.tenant)-clientSecret" $clientSecretFromEnv
}
else {
    Set-SecureSecret "$($config.cxOne.tenant)-clientSecret" (Read-Host "Client Secret")
}

# Save non-sensitive configuration to JSON
$config | ConvertTo-Json -Depth 5 | Out-File $configPath -Encoding utf8

# Configure email recipients
Write-Host "`nEnter recipient email addresses (comma-separated): "
$recipients = Read-Host
if ($recipients) {
    # One recipient per line for easy editing
    $recipients -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' } | Out-File "$PSScriptRoot\..\config\recipients.txt" -Encoding utf8
    Write-Host "Recipients saved to config\recipients.txt"
} else {
    Write-Host "Warning: No recipients configured. You'll need to add them to config\recipients.txt manually."
}

Write-Host "`nConfiguration complete!" -ForegroundColor Green

# Critical reminder about SYSTEM account access
Write-Host "`nIMPORTANT: If running as a service under SYSTEM account:" -ForegroundColor Yellow
Write-Host "  1. Run as Administrator: pwsh .\deploy\TestAsSystem.ps1"
Write-Host "  2. This will verify SYSTEM can access the credentials"
Write-Host "  3. If the test fails, re-run this configuration as Administrator"
