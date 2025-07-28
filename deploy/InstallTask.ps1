# InstallTask.ps1
# This script creates a scheduled task to run the MailerWorker script at system startup.

param(
    [string]$TaskName = "CxMailer",
    [string]$Interval = "PT15S"
)
$script = "$PSScriptRoot\..\src\MailerWorker.ps1"
$cmd    = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$script`""
schtasks /Create /TN $TaskName /SC ONSTART /TR "$cmd" /RL HIGHEST /F
Write-Output "Scheduled task '$TaskName' created."


#Run pwsh .\src\InstallConfiguration.ps1 to configure tenant, region, client-id, and client-secret.

#Execute pwsh .\deploy\InstallTask.ps1 to register the always-on scheduled task.

#Verify events in Windows Event Viewer → Application under source CxMailer.

#To remove, run pwsh .\deploy\UninstallTask.ps1