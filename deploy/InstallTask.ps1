# InstallTask.ps1
# This script creates a scheduled task to run the MailerWorker script at system startup.

param(
    [string]$TaskName = "CxMailer",
    [string]$Interval = "PT30S"
)
$script = "$PSScriptRoot\..\src\MailerWorker.ps1"
$cmd    = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
schtasks /Create /TN $TaskName /SC ONSTART /TR "$cmd" /RL HIGHEST /RU SYSTEM /F

# Start the task immediately so it begins processing without a reboot
#schtasks /Run /TN $TaskName | Out-Null
#Write-Output "Scheduled task '$TaskName' created and started under SYSTEM."


#Run pwsh .\src\InstallConfiguration.ps1 to configure tenant, region, client-id, and client-secret.
#Run pwsh .\src\MailerWorker.ps1 -TestMode to run in test mode without scheduling.
#Execute pwsh .\deploy\InstallTask.ps1 to register the always-on scheduled task.
#Verify events in Windows Event Viewer → Application under source CxMailer.
#To remove, run pwsh .\deploy\UninstallTask.ps1
#Deep-Clean Script: pwsh .\deploy\Cleanup.ps1