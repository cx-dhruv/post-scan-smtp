param(
    [string]$ConfigPath = "$PSScriptRoot\..\config\config.json",
    [switch]$TestMode
)

Import-Module "$PSScriptRoot\MailerCore.psm1" -Force
Import-Module "$PSScriptRoot\..\config\SecureConfig.psm1" -Force
Use-EnvFile "$PSScriptRoot\..\config\.env"

$ErrorActionPreference = 'Stop'

$cfg      = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
$interval = [int]$cfg.scheduleInSeconds
$source   = $cfg.logging.eventLogSource

if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
    New-EventLog -LogName Application -Source $source
}

if ($TestMode) {
    Write-Host "Running in test mode."
    try {
        Invoke-Mailer $cfg
        Write-Host "Test mode execution completed."
    } catch {
        Write-Host "Error during test mode execution: $_"
    }
    exit
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
