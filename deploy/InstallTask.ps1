# InstallTask.ps1
# This script creates a scheduled task to run the MailerWorker script at system startup.

param(
    [string]$TaskName = "CxMailer",
    [string]$Interval = "PT30S"
)

# Require administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

$script = "$PSScriptRoot\..\src\MailerWorker.ps1"
$workingDir = (Get-Item "$PSScriptRoot\..").FullName

Write-Host "Creating scheduled task '$TaskName'..." -ForegroundColor Green
Write-Host "Script path: $script" -ForegroundColor Cyan
Write-Host "Working directory: $workingDir" -ForegroundColor Cyan

# Create scheduled task with working directory
$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>CxMailer service that monitors Checkmarx scans and sends email notifications</Description>
  </RegistrationInfo>
  <Triggers>
    <BootTrigger>
      <Enabled>true</Enabled>
    </BootTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
    <RestartOnFailure>
      <Interval>PT1M</Interval>
      <Count>3</Count>
    </RestartOnFailure>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "$script"</Arguments>
      <WorkingDirectory>$workingDir</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@

# Save the XML to a temporary file
$tempXmlFile = [System.IO.Path]::GetTempFileName()
$taskXml | Out-File -FilePath $tempXmlFile -Encoding Unicode

# Import the task from XML
schtasks /Create /TN $TaskName /XML $tempXmlFile /F

# Clean up temp file
Remove-Item $tempXmlFile -Force -ErrorAction SilentlyContinue

if ($LASTEXITCODE -eq 0) {
    Write-Host "Scheduled task '$TaskName' created successfully!" -ForegroundColor Green
    Write-Host "The task will run at system startup under the SYSTEM account." -ForegroundColor Cyan
    
    # Offer to start the task immediately
    $start = Read-Host "`nStart the task now? (y/n)"
    if ($start -eq 'y') {
        schtasks /Run /TN $TaskName | Out-Null
        Write-Host "Task started. Check Event Viewer and logs for status." -ForegroundColor Green
    }
} else {
    Write-Host "Failed to create scheduled task. Error code: $LASTEXITCODE" -ForegroundColor Red
}

Write-Host "`n=== Installation Instructions ===" -ForegroundColor Yellow
Write-Host "1. First Time Setup:"
Write-Host "   pwsh .\src\InstallConfiguration.ps1  # Configure credentials and settings"
Write-Host ""
Write-Host "2. If you see 'Secret not found' errors:"
Write-Host "   pwsh .\deploy\FixCredentials.ps1     # Migrate credentials for SYSTEM access"
Write-Host ""
Write-Host "3. Test the service:"
Write-Host "   pwsh .\src\MailerWorker.ps1 -TestMode"
Write-Host ""
Write-Host "4. Monitor the service:"
Write-Host "   - Event Viewer -> Application -> Source: CxMailer"
Write-Host "   - Log file: .\logs\service.log"
Write-Host ""
Write-Host "5. Manage the service:"
Write-Host "   - Uninstall: pwsh .\deploy\UninstallTask.ps1"
Write-Host "   - Deep clean: pwsh .\deploy\Cleanup.ps1"



#The proper installation sequence is now:
#pwsh .\src\InstallConfiguration.ps1 - Configure credentials
#pwsh .\deploy\InstallTask.ps1 - Install the scheduled task
#The service will now work correctly on reboot