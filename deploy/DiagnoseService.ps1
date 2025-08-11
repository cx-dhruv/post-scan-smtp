# DiagnoseService.ps1
# This script helps diagnose issues with the CxMailer service

param(
    [switch]$AsSystem
)

# Require administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "`n=== CxMailer Service Diagnostics ===" -ForegroundColor Cyan
Write-Host "Current user: $env:USERNAME"
Write-Host "Computer: $env:COMPUTERNAME"
Write-Host "Working directory: $PWD"

# Create diagnostic script
$diagScript = @'
$ErrorActionPreference = 'Continue'
$logFile = "$env:ProgramData\CxMailer\diagnostic.log"

function Write-Diag {
    param($Message)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append -Encoding utf8
}

Write-Diag "=== Diagnostic Run Started ==="
Write-Diag "User: $env:USERNAME"
Write-Diag "Computer: $env:COMPUTERNAME"
Write-Diag "Working Directory: $PWD"
Write-Diag "PSScriptRoot: $PSScriptRoot"
Write-Diag "MyInvocation.MyCommand.Path: $($MyInvocation.MyCommand.Path)"

# Check environment
Write-Diag "`nEnvironment Variables:"
Write-Diag "APPDATA: $env:APPDATA"
Write-Diag "ProgramData: $env:ProgramData"
Write-Diag "PATH: $env:PATH"

# Check if modules exist
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = if ($scriptPath) { Split-Path -Parent $scriptPath } else { $PWD }
Write-Diag "`nScript directory: $scriptDir"

$paths = @{
    "MailerWorker" = "$scriptDir\..\src\MailerWorker.ps1"
    "MailerCore" = "$scriptDir\..\src\MailerCore.psm1"
    "SecureConfig" = "$scriptDir\..\config\SecureConfig.psm1"
    "Config JSON" = "$scriptDir\..\config\config.json"
    "Recipients" = "$scriptDir\..\config\recipients.txt"
}

Write-Diag "`nFile existence check:"
foreach ($key in $paths.Keys) {
    $exists = Test-Path $paths[$key]
    Write-Diag "$key : $($paths[$key]) - Exists: $exists"
}

# Try to load SecureConfig module
Write-Diag "`nTrying to load SecureConfig module..."
try {
    $secureConfigPath = "$scriptDir\..\config\SecureConfig.psm1"
    if (Test-Path $secureConfigPath) {
        Import-Module $secureConfigPath -Force
        Write-Diag "SecureConfig module loaded successfully"
        
        # Test secret access
        Write-Diag "`nTesting secret access..."
        Test-SecureSecrets
    } else {
        Write-Diag "ERROR: SecureConfig module not found at: $secureConfigPath"
    }
} catch {
    Write-Diag "ERROR loading SecureConfig: $_"
}

# Check scheduled task
Write-Diag "`nScheduled Task Information:"
try {
    $task = Get-ScheduledTask -TaskName "CxMailer" -ErrorAction Stop
    Write-Diag "Task State: $($task.State)"
    Write-Diag "Task Path: $($task.TaskPath)"
    
    $taskInfo = Get-ScheduledTaskInfo -TaskName "CxMailer"
    Write-Diag "Last Run Time: $($taskInfo.LastRunTime)"
    Write-Diag "Last Result: $($taskInfo.LastTaskResult)"
    Write-Diag "Next Run Time: $($taskInfo.NextRunTime)"
} catch {
    Write-Diag "ERROR getting task info: $_"
}

Write-Diag "`n=== Diagnostic Run Completed ==="
Write-Host "Diagnostic information written to: $logFile" -ForegroundColor Green
'@

if ($AsSystem) {
    Write-Host "`nRunning diagnostics as SYSTEM..." -ForegroundColor Yellow
    
    $diagScriptPath = "$PSScriptRoot\SystemDiag.ps1"
    $diagScript | Out-File -FilePath $diagScriptPath -Force
    
    # Create scheduled task to run as SYSTEM
    $taskName = "CxMailerDiag"
    $workingDir = (Get-Item "$PSScriptRoot\..").FullName
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$diagScriptPath`"" -WorkingDirectory $workingDir
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $task = New-ScheduledTask -Action $action -Principal $principal
    
    Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
    
    Write-Host "Waiting for diagnostic to complete..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
    # Clean up
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Remove-Item $diagScriptPath -Force
    
    # Display results
    $logFile = "$env:ProgramData\CxMailer\diagnostic.log"
    if (Test-Path $logFile) {
        Write-Host "`n=== SYSTEM Diagnostic Results ===" -ForegroundColor Cyan
        Get-Content $logFile | Write-Host
        
        # Archive the log
        $archivePath = "$PSScriptRoot\..\logs\system-diagnostic-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        Copy-Item $logFile $archivePath -Force
        Write-Host "`nDiagnostic log archived to: $archivePath" -ForegroundColor Green
    }
} else {
    Write-Host "`nRunning diagnostics as current user..." -ForegroundColor Yellow
    
    # Run diagnostic directly
    $scriptBlock = [ScriptBlock]::Create($diagScript)
    & $scriptBlock
    
    Write-Host "`nTo run diagnostics as SYSTEM, use: .\DiagnoseService.ps1 -AsSystem" -ForegroundColor Yellow
}

# Check recent Event Viewer errors
Write-Host "`n=== Recent CxMailer Events ===" -ForegroundColor Cyan
try {
    $events = Get-EventLog -LogName Application -Source "CxMailer" -Newest 10 -ErrorAction Stop
    foreach ($evt in $events) {
        $color = if ($evt.EntryType -eq "Error") { "Red" } else { "Gray" }
        Write-Host "$($evt.TimeGenerated) [$($evt.EntryType)] $($evt.Message)" -ForegroundColor $color
    }
} catch {
    Write-Host "No recent CxMailer events found or unable to access Event Log" -ForegroundColor Gray
}
