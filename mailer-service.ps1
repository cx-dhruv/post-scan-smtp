param (
    [ValidateSet("install", "uninstall", "run-once", "test")]
    [string]$action
)

switch ($action) {
    "install" {
        . "$PSScriptRoot\InstallMailerService.ps1"
    }
    "uninstall" {
        sc.exe stop MailerService
        sc.exe delete MailerService
        Write-Host "Service removed."
    }
    "run-once" {
        Import-Module -Name "$PSScriptRoot\mailer-core.psm1" -Force
        Invoke-Mailer
    }
    "test" {
        Import-Module -Name "$PSScriptRoot\mailer-core.psm1" -Force
        Log-Activity "Test log message. Service is working."
        Write-Host "Test completed. Check logs/service.log"
    }
}
