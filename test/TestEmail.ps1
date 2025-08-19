# Test script to verify email with embedded images
param(
    [string]$RecipientEmail
)

# Import the module and SecureConfig
$modulePath = (Resolve-Path "$PSScriptRoot\..\src\MailerCore.psm1").Path
Import-Module $modulePath -Force

# Import SecureConfig functions
Import-Module "$PSScriptRoot\..\config\SecureConfig.psm1" -Force

# Load config
$configPath = "$PSScriptRoot\..\config\config.json"
if (-not (Test-Path $configPath)) {
    Write-Host "Config file not found. Please run InstallConfiguration.ps1 first." -ForegroundColor Red
    exit 1
}

$config = Get-Content -Raw -Path $configPath | ConvertFrom-Json

# Create test data
$testDetails = @{
    projectName = "cx-dhruv/post-scan-smtp"
    riskScore = 85
    statistics = @{
        high = 3
        medium = 7
        low = 15
        info = 22
    }
}

$testScan = @{
    status = "Completed"
}

# Generate test email body
$localNow = (Get-Date).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")
$body = Get-EncodedTemplate "$PSScriptRoot\..\templates\notification_template.html" @{
    Project   = $testDetails.projectName
    Status    = $testScan.status
    RiskScore = $testDetails.riskScore
    Summary   = ($testDetails.statistics | ConvertTo-Json -Compress)
    TimeUtc   = $localNow
}

# If recipient email provided, override the recipients file temporarily
if ($RecipientEmail) {
    Write-Host "Sending test email to: $RecipientEmail" -ForegroundColor Green
    $originalRecipients = Get-Content "$PSScriptRoot\..\config\recipients.txt" -ErrorAction SilentlyContinue
    $RecipientEmail | Out-File "$PSScriptRoot\..\config\recipients.txt" -Force
}

try {
    # Send the test email
    Send-SecureMail $config "TEST: Checkmarx scan completed" $body
    Write-Host "Test email sent successfully!" -ForegroundColor Green
    
    # Save the generated HTML for debugging
    $body | Out-File "$PSScriptRoot\test_email.html" -Force
    Write-Host "Test email HTML saved to: test\test_email.html" -ForegroundColor Cyan
}
catch {
    Write-Host "Error sending test email: $_" -ForegroundColor Red
}
finally {
    # Restore original recipients if we changed them
    if ($RecipientEmail -and $originalRecipients) {
        $originalRecipients | Out-File "$PSScriptRoot\..\config\recipients.txt" -Force
    }
}
