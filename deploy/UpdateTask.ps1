# UpdateTask.ps1
# This script updates the existing CxMailer scheduled task with the correct working directory

param(
    [string]$TaskName = "CxMailer"
)

# Require administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "`n=== CxMailer Task Update Tool ===" -ForegroundColor Cyan
Write-Host "This will update the scheduled task to fix the 'path not found' error.`n"

# Check if task exists
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-Host "Found existing task. Current state: $($existingTask.State)" -ForegroundColor Yellow
    
    # Stop the task if running
    if ($existingTask.State -eq "Running") {
        Write-Host "Stopping the task..." -ForegroundColor Yellow
        Stop-ScheduledTask -TaskName $TaskName
        Start-Sleep -Seconds 2
    }
    
    # Delete the old task
    Write-Host "Removing old task configuration..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
} else {
    Write-Host "No existing task found. Will create new one." -ForegroundColor Green
}

Write-Host "`nRecreating task with correct configuration..." -ForegroundColor Green

# Run the install script
& "$PSScriptRoot\InstallTask.ps1" -TaskName $TaskName

Write-Host "`n=== Update Complete ===" -ForegroundColor Green
Write-Host "The scheduled task has been updated with the correct working directory."
Write-Host "The 'path not found' error should now be resolved."
Write-Host "`nYou can verify this by checking:"
Write-Host "  - Event Viewer -> Application Log -> CxMailer (should show no path errors)"
Write-Host "  - Task Scheduler -> CxMailer task properties -> Actions tab"
Write-Host "    (Should show 'Start in' field with the correct path)`n"
