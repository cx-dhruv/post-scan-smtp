# InstallTask.ps1
# This script creates a scheduled task to run the MailerWorker script at system startup
# and also triggers it immediately after installation.

param(
    [string]$TaskName = "CxMailer",
    [string]$Interval = "PT15S"
)

$script = "$PSScriptRoot\..\src\MailerWorker.ps1"
$cmd    = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$script`""

# Create the task to run on startup
schtasks /Create /TN $TaskName /SC ONSTART /TR "$cmd" /RL HIGHEST /F

if ($LASTEXITCODE -eq 0) {
    Write-Output "Scheduled task '$TaskName' created successfully."

    # Run it immediately without reboot
    schtasks /Run /TN $TaskName
    if ($LASTEXITCODE -eq 0) {
        Write-Output "Scheduled task '$TaskName' started immediately."
    } else {
        Write-Output "Scheduled task '$TaskName' was created but could not be started immediately."
    }
} else {
    Write-Output "Failed to create scheduled task '$TaskName'."
}

# Instructions:
# Run pwsh .\src\InstallConfiguration.ps1 to configure tenant, region, client-id, and client-secret.
# Run pwsh .\src\MailerWorker.ps1 -TestMode to run in test mode without scheduling.
# Execute pwsh .\deploy\InstallTask.ps1 to register the always-on scheduled task.
# Verify events in Windows Event Viewer → Application under source CxMailer.
# To remove, run pwsh .\deploy\UninstallTask.ps1
