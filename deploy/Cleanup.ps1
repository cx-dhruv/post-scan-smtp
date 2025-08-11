# CxMailer Full Cleanup Script

Write-Host "=== Stopping running CxMailer processes ==="
Get-Process powershell, pwsh -ErrorAction SilentlyContinue |
    Where-Object {
        try {
            $_.Path -and (Get-Content -Path $_.Path -ErrorAction SilentlyContinue | Select-String "CxMailer")
        } catch { $false }
    } |
    ForEach-Object {
        Write-Host "Killing process ID $($_.Id)..."
        Stop-Process -Id $_.Id -Force
    }

Write-Host "=== Removing CxMailer scheduled tasks (all users & SYSTEM) ==="
schtasks /Query /FO LIST /V | findstr /I "CxMailer" | ForEach-Object {
    $taskName = ($_ -split ":")[1].Trim()
    if ($taskName) {
        try {
            schtasks /Delete /TN "$taskName" /F
            Write-Host "Deleted scheduled task: $taskName"
        } catch {
            Write-Host "Failed to delete scheduled task: $taskName"
        }
    }
}

Write-Host "=== Removing CxMailer services if any ==="
Get-Service | Where-Object { $_.DisplayName -like "*CxMailer*" -or $_.Name -like "*CxMailer*" } |
    ForEach-Object {
        Write-Host "Stopping and deleting service: $($_.Name)"
        try { Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue } catch {}
        sc.exe delete "$($_.Name)" | Out-Null
    }

Write-Host "=== Removing CxMailer Event Log source ==="
if ([System.Diagnostics.EventLog]::SourceExists("CxMailer")) {
    try {
        [System.Diagnostics.EventLog]::DeleteEventSource("CxMailer")
        Write-Host "Event log source 'CxMailer' removed."
    } catch {
        Write-Host "Failed to remove event log source."
    }
}

Write-Host "=== Cleanup complete ==="
