# MailerWorker.ps1
# Main entry point for the CxMailer service
# Runs continuously as a Windows scheduled task under SYSTEM account

param(
    [string]$ConfigPath,     # Optional path to config.json
    [switch]$TestMode        # Run once for testing instead of continuous loop
)

# Determine script directory reliably across different execution contexts
# This handles direct execution, scheduled tasks, and SYSTEM account scenarios
$scriptDir = if ($PSScriptRoot) {
    $PSScriptRoot
} else {
    $scriptPath = $MyInvocation.MyCommand.Path
    if ($scriptPath) {
        Split-Path -Parent $scriptPath
    } else {
        # Fallback for edge cases (e.g., dot-sourcing)
        "$PWD\src"
    }
}

# Import core module with explicit path to avoid PowerShell module resolution issues
# Critical for SYSTEM account where user module paths may not be available
$mailerCorePath = "$scriptDir\MailerCore.psm1"

if (-not (Test-Path $mailerCorePath)) {
    Write-Host "ERROR: MailerCore module not found at: $mailerCorePath"
    throw "Cannot find MailerCore module"
}

Import-Module $mailerCorePath -Force

# Load optional .env file for development/testing scenarios
# Production deployments should use InstallConfiguration.ps1 instead
$envFile = "$scriptDir\..\config\.env"
if (Test-Path $envFile) {
    Use-EnvFile $envFile
}

# Fail fast on any error to prevent silent failures
$ErrorActionPreference = 'Stop'

# Set default ConfigPath if not provided
if (-not $ConfigPath) {
    $ConfigPath = "$scriptDir\..\config\config.json"
}

if (-not (Test-Path $ConfigPath)) {
    Write-Host "ERROR: Config file not found at: $ConfigPath"
    throw "Cannot find config file"
}

# Load configuration settings
$cfg      = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
$interval = [int]$cfg.scheduleInSeconds  # How often to check for new scans
$source   = $cfg.logging.eventLogSource   # Windows Event Log source name

# Register event log source if not already present
# Required for writing to Windows Event Viewer
if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
    New-EventLog -LogName Application -Source $source
}

# Test mode for validation and troubleshooting
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

# Main service loop - runs indefinitely
while ($true) {
    try {
        # Poll Checkmarx API and send notifications for new scans
        Invoke-Mailer $cfg
    }
    catch {
        # Log errors to Event Viewer for monitoring
        # Event ID 1001 can be used for alerting/monitoring
        Write-EventLog -LogName Application -Source $source -EntryType Error `
                       -EventId 1001 -Message $_.Exception.Message
        
        # Exponential backoff on errors to prevent API flooding
        foreach ($backoff in 5,15,30) { Start-Sleep $backoff }
    }
    
    # Wait for configured interval before next check
    Start-Sleep -Seconds $interval
}
