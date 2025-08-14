# RestartService.ps1
# Stops and restarts the CxMailer service to pick up code changes

param(
    [string]$TaskName = "CxMailer"
)

# Require administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Restarting CxMailer Service ===" -ForegroundColor Cyan

# Check if task exists
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if (-not $task) {
    Write-Host "Task '$TaskName' not found. Please run InstallTask.ps1 first." -ForegroundColor Red
    exit 1
}

Write-Host "Current task state: $($task.State)" -ForegroundColor Yellow

# Stop the task
if ($task.State -eq "Running") {
    Write-Host "Stopping task..." -ForegroundColor Yellow
    Stop-ScheduledTask -TaskName $TaskName
    
    # Wait for task to stop
    $maxWait = 30
    $waited = 0
    while ((Get-ScheduledTask -TaskName $TaskName).State -eq "Running" -and $waited -lt $maxWait) {
        Start-Sleep -Seconds 1
        $waited++
        Write-Host "." -NoNewline
    }
    Write-Host ""
    
    if ($waited -eq $maxWait) {
        Write-Host "Warning: Task did not stop within $maxWait seconds" -ForegroundColor Yellow
    } else {
        Write-Host "Task stopped successfully" -ForegroundColor Green
    }
}

# Clear any cached modules
Write-Host "Clearing module cache..." -ForegroundColor Yellow
Get-Module -Name "MailerCore", "SecureConfig" | Remove-Module -Force -ErrorAction SilentlyContinue

# Clear the diagnostic log
$diagLog = "$env:ProgramData\CxMailer\diagnostic.log"
if (Test-Path $diagLog) {
    Remove-Item $diagLog -Force
    Write-Host "Cleared diagnostic log" -ForegroundColor Gray
}

# Start the task
Write-Host "Starting task..." -ForegroundColor Yellow
Start-ScheduledTask -TaskName $TaskName

# Verify it started
Start-Sleep -Seconds 2
$newState = (Get-ScheduledTask -TaskName $TaskName).State
Write-Host "New task state: $newState" -ForegroundColor $(if ($newState -eq "Running") { "Green" } else { "Red" })

if ($newState -eq "Running") {
    Write-Host "`nService restarted successfully!" -ForegroundColor Green
    Write-Host "`nMonitor the service:" -ForegroundColor Cyan
    Write-Host "  - Check Event Viewer for any errors"
    Write-Host "  - Watch logs\service.log for activity"
    Write-Host "  - Run .\deploy\DiagnoseService.ps1 -AsSystem for detailed diagnostics"
} else {
    Write-Host "`nService failed to start!" -ForegroundColor Red
    Write-Host "Run .\deploy\DiagnoseService.ps1 -AsSystem for diagnostics" -ForegroundColor Yellow
}
