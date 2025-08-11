Import-Module "$PSScriptRoot\..\config\SecureConfig.psm1" -Force -DisableNameChecking

$configPath = "$PSScriptRoot\..\config\config.json"
$sampleConfigPath = "$PSScriptRoot\..\config\config.sample.json"
$envPath = "$PSScriptRoot\..\config\.env"

# Load config.json if valid, else use sample
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
$useDefaultSmtp = Read-Host "Use default SMTP settings? (y/n)"
if ($useDefaultSmtp -eq 'y') {
    $config.smtp.server = [System.Environment]::GetEnvironmentVariable("SERVER")
    $config.smtp.port = [System.Environment]::GetEnvironmentVariable("PORT")
    $config.smtp.username = [System.Environment]::GetEnvironmentVariable("USERNAME")
    $config.smtp.password = [System.Environment]::GetEnvironmentVariable("PASSWORD")
}
else {
    $config.smtp.server = Read-Host "SMTP server address"
    $config.smtp.port = [int](Read-Host "SMTP server port")
    $config.smtp.username = Read-Host "SMTP username"
    $config.smtp.password = Read-Host "SMTP password"
}

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
$regionFromEnv = [System.Environment]::GetEnvironmentVariable("CX_REGION")
if (-not [string]::IsNullOrWhiteSpace($regionFromEnv)) { $config.cxOne.region = $regionFromEnv }

$tenantFromEnv = [System.Environment]::GetEnvironmentVariable("CX_TENANT")
if (-not [string]::IsNullOrWhiteSpace($tenantFromEnv)) { $config.cxOne.tenant = $tenantFromEnv }

$clientIdFromEnv = [System.Environment]::GetEnvironmentVariable("CX_CLIENT_ID")
$clientSecretFromEnv = [System.Environment]::GetEnvironmentVariable("CX_CLIENT_SECRET")

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

$config | ConvertTo-Json -Depth 5 | Out-File $configPath -Encoding utf8

Write-Host "Enter recipient addresses (comma-separated): "
(Read-Host) -split ',' | Out-File "$PSScriptRoot\..\config\recipients.txt" -Encoding utf8

Write-Host "Configuration complete."
