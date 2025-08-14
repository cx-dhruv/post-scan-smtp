# QuickConfig.ps1
# Quick configuration utility for CxMailer credentials

param(
    [switch]$UseDefaults
)

# Require administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "`n=== CxMailer Quick Configuration ===" -ForegroundColor Cyan

# Load MailerCore module which has the embedded functions
Import-Module "$PSScriptRoot\..\src\MailerCore.psm1" -Force

# Ensure secrets directory exists
$secretsPath = "$env:ProgramData\CxMailer\Secrets"
if (-not (Test-Path $secretsPath)) {
    New-Item -ItemType Directory -Path $secretsPath -Force | Out-Null
    Write-Host "Created secrets directory: $secretsPath" -ForegroundColor Green
}

# Function to store a secret
function Store-Secret {
    param($Key, $Secret)
    
    if (-not $Secret) {
        Write-Host "Skipping empty secret: $Key" -ForegroundColor Yellow
        return
    }
    
    $filePath = "$secretsPath\$Key.txt"
    
    try {
        # Get machine key
        $machineGuid = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name MachineGuid).MachineGuid
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($machineGuid)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $machineKey = $sha256.ComputeHash($bytes)
        $sha256.Dispose()
        
        # Encrypt the secret
        $secureString = ConvertTo-SecureString -String $Secret -AsPlainText -Force
        $encryptedString = ConvertFrom-SecureString -SecureString $secureString -Key $machineKey
        
        # Save to file
        $encryptedString | Out-File -FilePath $filePath -Force
        Write-Host "Stored secret: $Key" -ForegroundColor Green
    }
    catch {
        Write-Host "Error storing secret $Key`: $_" -ForegroundColor Red
    }
}

# Load existing config
$configPath = "$PSScriptRoot\..\config\config.json"
if (Test-Path $configPath) {
    $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
    Write-Host "Loaded existing configuration" -ForegroundColor Gray
} else {
    Write-Host "No existing config found. Please run InstallConfiguration.ps1 first." -ForegroundColor Red
    exit 1
}

# SMTP Credentials
Write-Host "`n=== SMTP Credentials ===" -ForegroundColor Yellow

if ($UseDefaults) {
    Write-Host "Using environment variables for SMTP..." -ForegroundColor Gray
    $smtpServer = [System.Environment]::GetEnvironmentVariable("SERVER")
    $smtpUsername = [System.Environment]::GetEnvironmentVariable("USERNAME")
    $smtpPassword = [System.Environment]::GetEnvironmentVariable("PASSWORD")
} else {
    $smtpServer = Read-Host "SMTP Server (e.g., smtp.gmail.com)"
    $smtpUsername = Read-Host "SMTP Username"
    $smtpPassword = Read-Host "SMTP Password" -AsSecureString
    $smtpPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($smtpPassword))
}

if ($smtpServer) { Store-Secret "smtp-server" $smtpServer }
if ($smtpUsername) { Store-Secret "smtp-username" $smtpUsername }
if ($smtpPassword) { Store-Secret "smtp-password" $smtpPassword }

# Checkmarx Credentials
Write-Host "`n=== Checkmarx One Credentials ===" -ForegroundColor Yellow
Write-Host "Tenant: $($config.cxOne.tenant)" -ForegroundColor Gray
Write-Host "Region: $($config.cxOne.region)" -ForegroundColor Gray

$clientId = Read-Host "`nClient ID"
$clientSecret = Read-Host "Client Secret"

if ($clientId) { Store-Secret "$($config.cxOne.tenant)-clientId" $clientId }
if ($clientSecret) { Store-Secret "$($config.cxOne.tenant)-clientSecret" $clientSecret }

# Recipients
Write-Host "`n=== Email Recipients ===" -ForegroundColor Yellow
$recipientsPath = "$PSScriptRoot\..\config\recipients.txt"
if (Test-Path $recipientsPath) {
    $existing = Get-Content $recipientsPath
    Write-Host "Existing recipients: $($existing -join ', ')" -ForegroundColor Gray
}

$newRecipients = Read-Host "Enter recipient emails (comma-separated, or press Enter to keep existing)"
if ($newRecipients) {
    $newRecipients -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' } | Out-File $recipientsPath -Encoding utf8
    Write-Host "Updated recipients" -ForegroundColor Green
}

Write-Host "`n=== Configuration Complete ===" -ForegroundColor Green

# Test credential access
Write-Host "`nTesting credential access..." -ForegroundColor Yellow
$testKeys = @("smtp-server", "smtp-username", "$($config.cxOne.tenant)-clientId")
foreach ($key in $testKeys) {
    try {
        $value = Get-SecureSecret -Key $key
        Write-Host "  ✓ $key - accessible" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ $key - not accessible" -ForegroundColor Red
    }
}

Write-Host "`nConfiguration is ready! The service should now work correctly." -ForegroundColor Green
