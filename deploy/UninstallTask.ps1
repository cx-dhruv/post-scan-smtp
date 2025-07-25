param([string]$TaskName = "CxMailer")
schtasks /Delete /TN $TaskName /F
Write-Output "Scheduled task '$TaskName' removed."
