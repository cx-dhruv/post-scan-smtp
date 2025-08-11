# FixCredentials.ps1
# This script ensures credentials are properly stored for the CxMailer service

param(
    [switch]$Force
)

# Require administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

Import-Module "$PSScriptRoot\..\config\SecureConfig.psm1" -Force

Write-Host "`n=== CxMailer Credential Configuration Tool ===" -ForegroundColor Cyan
Write-Host "This tool will ensure your credentials are properly stored for the service.`n"

# Check if service is running
$taskName = "CxMailer"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($task -and $task.State -eq "Running") {
    Write-Host "Stopping CxMailer service..." -ForegroundColor Yellow
    Stop-ScheduledTask -TaskName $taskName
    Start-Sleep -Seconds 2
}

# Test current credential accessibility
Test-SecureSecrets

# Always run configuration to ensure credentials are set up
Write-Host "`nRunning credential configuration..." -ForegroundColor Yellow
& "$PSScriptRoot\..\src\InstallConfiguration.ps1"

Write-Host "`nTesting credential accessibility after configuration..." -ForegroundColor Green
Test-SecureSecrets

# Restart the service if it was running
if ($task) {
    Write-Host "`nRestarting CxMailer service..." -ForegroundColor Yellow
    Start-ScheduledTask -TaskName $taskName
    Write-Host "Service restarted successfully." -ForegroundColor Green
}

Write-Host "`nConfiguration complete!" -ForegroundColor Green
Write-Host "`nYou can verify the service is working by checking:" -ForegroundColor Cyan
Write-Host "  1. Windows Event Viewer -> Application Log -> CxMailer events"
Write-Host "  2. The service log at: $PSScriptRoot\..\logs\service.log"
Write-Host "  3. Run test mode: pwsh $PSScriptRoot\..\src\MailerWorker.ps1 -TestMode`n"