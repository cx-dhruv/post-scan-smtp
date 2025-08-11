# TestAsSystem.ps1
# This script tests if credentials are accessible when running as SYSTEM

param(
    [string]$TaskName = "CxMailerTest"
)

# Require administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Testing Credential Access as SYSTEM ===" -ForegroundColor Cyan

# Create a test script that will run as SYSTEM
$testScript = @'
Import-Module "$PSScriptRoot\..\config\SecureConfig.psm1" -Force

Write-Host "`nRunning as: $env:USERNAME (should be empty or SYSTEM)"
Write-Host "Computer: $env:COMPUTERNAME"

try {
    Test-SecureSecrets
    Write-Host "`nCredentials are accessible to SYSTEM account!" -ForegroundColor Green
}
catch {
    Write-Host "`nError accessing credentials as SYSTEM: $_" -ForegroundColor Red
}
'@

$testScriptPath = "$PSScriptRoot\SystemTest.ps1"
$testScript | Out-File -FilePath $testScriptPath -Force

# Create a temporary scheduled task to run as SYSTEM
Write-Host "Creating temporary test task..." -ForegroundColor Yellow
$workingDir = (Get-Item "$PSScriptRoot\..").FullName
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$testScriptPath`"" -WorkingDirectory $workingDir
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$task = New-ScheduledTask -Action $action -Principal $principal

Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null

# Run the task
Write-Host "Running test as SYSTEM..." -ForegroundColor Yellow
Start-ScheduledTask -TaskName $TaskName

# Wait for completion
Start-Sleep -Seconds 3

# Get task result
$taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
Write-Host "`nTask completed with result: $($taskInfo.LastTaskResult)" -ForegroundColor Cyan

# Clean up
Write-Host "Cleaning up test task..." -ForegroundColor Yellow
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
Remove-Item $testScriptPath -Force

Write-Host "`nTest complete! Check the output above to see if SYSTEM can access credentials." -ForegroundColor Green
Write-Host "If successful, your CxMailer service should work correctly.`n"
