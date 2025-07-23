param (
    [string]$ServiceName = "MailerService",
    [string]$DisplayName = "SMTP Mailer API Service",
    [string]$Description = "Monitors Checkmarx scan queue and sends emails"
)

$script = "$PSScriptRoot\MailerWorker.ps1"
$binPath = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$script`""

sc.exe create $ServiceName binPath= "$binPath" start= auto DisplayName= "$DisplayName"
sc.exe description $ServiceName "$Description"

Write-Output "Service '$ServiceName' installed. Start it with: Start-Service $ServiceName"
