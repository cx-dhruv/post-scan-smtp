# SetupCredentials.ps1
# Direct credential setup for CxMailer

Write-Host "`n=== Setting up CxMailer Credentials ===" -ForegroundColor Cyan

# Create directories
$secretsPath = "$env:ProgramData\CxMailer\Secrets"
New-Item -ItemType Directory -Path $secretsPath -Force -ErrorAction SilentlyContinue | Out-Null
Write-Host "Created directory: $secretsPath" -ForegroundColor Green

# Function to encrypt and store
function Store-Credential {
    param($Key, $Value)
    
    if (-not $Value) {
        Write-Host "Skipping empty value for: $Key" -ForegroundColor Yellow
        return
    }
    
    try {
        # Get machine key
        $machineGuid = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name MachineGuid).MachineGuid
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($machineGuid)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $machineKey = $sha256.ComputeHash($bytes)
        $sha256.Dispose()
        
        # Encrypt
        $secureString = ConvertTo-SecureString -String $Value -AsPlainText -Force
        $encrypted = ConvertFrom-SecureString -SecureString $secureString -Key $machineKey
        
        # Save
        $filePath = "$secretsPath\$Key.txt"
        $encrypted | Out-File -FilePath $filePath -Force
        Write-Host "Stored: $Key" -ForegroundColor Green
    }
    catch {
        Write-Host "Error storing $Key`: $_" -ForegroundColor Red
    }
}

# Get values from environment or prompt
Write-Host "`nEnter credentials (press Enter to use environment variables):" -ForegroundColor Yellow

# SMTP
$smtpServer = Read-Host "SMTP Server (default: smtp.gmail.com)"
if (-not $smtpServer) { $smtpServer = "smtp.gmail.com" }

$smtpUser = Read-Host "SMTP Username"
if (-not $smtpUser -and $env:USERNAME) { $smtpUser = $env:USERNAME }

$smtpPass = Read-Host "SMTP Password" -AsSecureString
if ($smtpPass.Length -eq 0 -and $env:PASSWORD) { 
    $smtpPass = $env:PASSWORD 
} else {
    $smtpPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($smtpPass))
}

# Checkmarx
$tenant = Read-Host "Checkmarx Tenant (default: sudha)"
if (-not $tenant) { $tenant = "sudha" }

$clientId = Read-Host "Client ID"
$clientSecret = Read-Host "Client Secret"

# Store all credentials
Store-Credential "smtp-server" $smtpServer
Store-Credential "smtp-username" $smtpUser
Store-Credential "smtp-password" $smtpPass
Store-Credential "$tenant-clientId" $clientId
Store-Credential "$tenant-clientSecret" $clientSecret

Write-Host "`n=== Credentials stored successfully! ===" -ForegroundColor Green
Write-Host "Files created in: $secretsPath" -ForegroundColor Cyan
Get-ChildItem $secretsPath | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
