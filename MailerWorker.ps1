Import-Module -Name "$PSScriptRoot\mailer-core.psm1" -Force
$ErrorActionPreference = "Stop"

while ($true) {
    try {
        Invoke-Mailer
    } catch {
        Log-Activity "Error occurred: $_"
    }

    $config = Get-Content -Raw -Path "$PSScriptRoot\config.json" | ConvertFrom-Json
    Start-Sleep -Seconds ($config.scheduleInMinutes * 60)
}
