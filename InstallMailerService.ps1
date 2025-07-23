param (
    [string]$ServiceName = "MailerService",
    [string]$DisplayName = "SMTP Mailer API Service",
    [string]$Description = "Fetches API data and emails it periodically"
)

$exe = "powershell.exe"
$script = "$PSScriptRoot\MailerWorker.ps1"
$binPath = "$exe -NoProfile -ExecutionPolicy Bypass -File `"$script`""

sc.exe create $ServiceName binPath= "$binPath" start= auto DisplayName= "$DisplayName"
sc.exe description $ServiceName "$Description"

Write-Output "Service '$ServiceName' installed. Start it with: Start-Service $ServiceName"
