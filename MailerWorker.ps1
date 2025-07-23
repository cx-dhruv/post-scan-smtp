Import-Module "$PSScriptRoot\mailer-core.psm1" -Force
$ErrorActionPreference = "Stop"

if (-not (Test-Path ".scans")) { New-Item ".scans" -ItemType Directory }

while ($true) {
    try {
        Invoke-Mailer
    } catch {
        Log-Activity -Message "Exception: $_"
    }

    $config = Get-Content "$PSScriptRoot\config.json" | ConvertFrom-Json
    Start-Sleep -Seconds 15
}
