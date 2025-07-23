$ConfigPath = "$PSScriptRoot\config.json"

Write-Host "Configuring your Checkmarx Mailer..."

# Load or initialize config
if (Test-Path $ConfigPath) {
    $config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
} else {
    $config = @{
        smtp  = @{ to = @() }
        cxOne = @{ region = ""; clientId = ""; clientSecret = ""; tenant = "sudha" }
    }
}

# Collect recipient emails
$config.smtp.to = @()
while ($true) {
    $email = Read-Host "Enter recipient email address"
    $config.smtp.to += $email
    if ((Read-Host "Add another? (y/n)") -ne 'y') { break }
}

# Checkmarx IAM & AST details
$config.cxOne.region       = Read-Host "Enter Checkmarx region (ind/eu/sng/mea)"
$config.cxOne.clientId     = Read-Host "Enter Checkmarx client ID"
$config.cxOne.clientSecret = Read-Host "Enter Checkmarx client secret"

# SMTP credentials
$config.smtp.server   = Read-Host "SMTP server"
$config.smtp.port     = Read-Host "SMTP port"
$config.smtp.username = Read-Host "SMTP username"
$config.smtp.password = Read-Host "SMTP password"
$config.smtp.from     = Read-Host "Sender email (FROM)"

# Save config
$config | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigPath -Encoding utf8

Write-Host "Configuration saved to $ConfigPath"
Write-Host "Now update 'template.html' to customize your email format."
