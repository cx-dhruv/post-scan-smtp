param(
    [string]$ConfigPath = "$PSScriptRoot\..\config\config.json"
)

Import-Module "$PSScriptRoot\MailerCore.psm1" -Force
$ErrorActionPreference = 'Stop'

$cfg      = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
$interval = [int]$cfg.scheduleInSeconds
$source   = $cfg.logging.eventLogSource

if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
    New-EventLog -LogName Application -Source $source
}

while ($true) {
    try {
        Invoke-Mailer $cfg
    }
    catch {
        Write-EventLog -LogName Application -Source $source -EntryType Error `
                       -EventId 1001 -Message $_.Exception.Message
        foreach ($backoff in 5,15,30) { Start-Sleep $backoff }
    }
    Start-Sleep -Seconds $interval
}
