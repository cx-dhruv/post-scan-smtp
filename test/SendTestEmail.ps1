# Script to send a test email through the actual Send-SecureMail function
param(
    [Parameter(Mandatory=$false)]
    [string]$ToEmail
)

# Import modules
$modulePath = (Resolve-Path "$PSScriptRoot\..\src\MailerCore.psm1").Path
Import-Module $modulePath -Force
Import-Module "$PSScriptRoot\..\config\SecureConfig.psm1" -Force -ErrorAction SilentlyContinue

# Initialize logging
$logDir = "$PSScriptRoot\..\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

Write-Host "Starting test email send..." -ForegroundColor Cyan

# Load config
$configPath = "$PSScriptRoot\..\config\config.json"
if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: Config not found. Run InstallConfiguration.ps1 first." -ForegroundColor Red
    exit 1
}

$config = Get-Content -Raw -Path $configPath | ConvertFrom-Json

# Override recipient if specified
$recipientFile = "$PSScriptRoot\..\config\recipients.txt"
$originalRecipients = $null
if ($ToEmail) {
    Write-Host "Overriding recipients with: $ToEmail" -ForegroundColor Yellow
    $originalRecipients = Get-Content $recipientFile -ErrorAction SilentlyContinue
    $ToEmail | Out-File $recipientFile -Force
}

try {
    # Create test scan data
    $testData = @{
        projectName = "cx-dhruv/post-scan-smtp"
        riskScore = 85
        statistics = @{
            high = 3
            medium = 7
            low = 15
            info = 22
        }
    }
    
    $scanStatus = "Completed"
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    
    # Generate HTML using the actual template
    $templatePath = "$PSScriptRoot\..\templates\notification_template.html"
    $htmlBody = Get-EncodedTemplate $templatePath @{
        Project = $testData.projectName
        Status = $scanStatus
        RiskScore = $testData.riskScore
        Summary = ($testData.statistics | ConvertTo-Json -Compress)
        TimeUtc = $timestamp
    }
    
    Write-Host "Generated HTML body with template" -ForegroundColor Green
    Write-Host "Calling Send-SecureMail..." -ForegroundColor Yellow
    
    # This will trigger the image embedding logic
    Send-SecureMail $config "TEST: Checkmarx scan completed (with embedded images)" $htmlBody
    
    Write-Host "`nTest email sent successfully!" -ForegroundColor Green
    Write-Host "Check your email inbox for the test message." -ForegroundColor Cyan
    
    # Check logs for image embedding confirmation
    Write-Host "`nChecking logs for image embedding..." -ForegroundColor Yellow
    $recentLogs = Get-Content "$PSScriptRoot\..\logs\service.log" -Tail 20
    $embedLogs = $recentLogs | Where-Object { $_ -match "Embedded.*logo|Warning.*logo" }
    
    if ($embedLogs) {
        Write-Host "Image embedding logs:" -ForegroundColor Green
        $embedLogs | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    } else {
        Write-Host "No image embedding logs found - checking if Send-SecureMail was called..." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "ERROR: Failed to send test email" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Gray
}
finally {
    # Restore original recipients
    if ($originalRecipients) {
        Write-Host "`nRestoring original recipients..." -ForegroundColor Gray
        $originalRecipients | Out-File $recipientFile -Force
    }
}

Write-Host "`nTest complete." -ForegroundColor Cyan
