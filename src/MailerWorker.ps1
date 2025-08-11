param(
    [string]$ConfigPath,
    [switch]$TestMode
)

# Get the directory of this script reliably
$scriptDir = if ($PSScriptRoot) {
    $PSScriptRoot
} else {
    $scriptPath = $MyInvocation.MyCommand.Path
    if ($scriptPath) {
        Split-Path -Parent $scriptPath
    } else {
        # Use working directory as fallback
        "$PWD\src"
    }
}

# Import modules with explicit paths
$mailerCorePath = "$scriptDir\MailerCore.psm1"

if (-not (Test-Path $mailerCorePath)) {
    Write-Host "ERROR: MailerCore module not found at: $mailerCorePath"
    throw "Cannot find MailerCore module"
}

Import-Module $mailerCorePath -Force

# Only load .env if it exists (optional file)
$envFile = "$scriptDir\..\config\.env"
if (Test-Path $envFile) {
    Use-EnvFile $envFile
}

$ErrorActionPreference = 'Stop'

# Set default ConfigPath if not provided
if (-not $ConfigPath) {
    $ConfigPath = "$scriptDir\..\config\config.json"
}

if (-not (Test-Path $ConfigPath)) {
    Write-Host "ERROR: Config file not found at: $ConfigPath"
    throw "Cannot find config file"
}

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
