param([string]$TaskName = "CxMailer")

try {
    schtasks /Query /TN $TaskName > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        schtasks /Delete /TN $TaskName /F
        Write-Output "Scheduled task '$TaskName' removed."
    }
    else {
        Write-Output "Scheduled task '$TaskName' not found."
    }
}
catch {
    Write-Output "Error while checking/removing scheduled task: $_"
}
