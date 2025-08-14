# CxMailer Installation Guide

CxMailer is a Windows service that monitors Checkmarx scans and sends email notifications when scans complete.

## Prerequisites

- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or later
- Administrator privileges for installation
- SMTP server access (e.g., Gmail, Office 365)
- Checkmarx One API credentials (client ID and secret)

## Installation Steps

### 1. Configure Credentials and Settings

Run as Administrator:
```powershell
pwsh .\src\InstallConfiguration.ps1
```

This will prompt you for:
- SMTP server settings (server, port, username, password)
- Checkmarx One credentials (region, tenant, client ID, client secret)
- Email recipient addresses

### 2. Test Credential Access

Verify that the SYSTEM account can access the stored credentials:
```powershell
pwsh .\deploy\TestAsSystem.ps1
```

If this test fails, ensure you ran the configuration script as Administrator.

### 3. Install the Service

Create the scheduled task that runs at system startup:
```powershell
pwsh .\deploy\InstallTask.ps1
```

When prompted, choose 'y' to start the service immediately.

### 4. Verify Installation

Check that the service is running correctly:

1. **Event Viewer**: Windows Logs → Application → Filter by source "CxMailer"
2. **Service Log**: Check `logs\service.log` for activity
3. **Test Mode**: Run `pwsh .\src\MailerWorker.ps1 -TestMode`

## Troubleshooting

### "Secret not found" Errors

If you see credential errors in the Event Viewer:
1. Run `pwsh .\deploy\FixCredentials.ps1` as Administrator
2. This will reconfigure credentials for SYSTEM access

### "Path not found" Errors

If you see path errors:
1. Run `pwsh .\deploy\UpdateTask.ps1` as Administrator
2. This updates the task with the correct working directory

### Testing Email Delivery

To test if emails are being sent:
1. Ensure you have completed scans in Checkmarx
2. Check `logs\service.log` for processing activity
3. Verify SMTP settings if emails aren't received

## Service Management

### Stop the Service
```powershell
Stop-ScheduledTask -TaskName CxMailer
```

### Start the Service
```powershell
Start-ScheduledTask -TaskName CxMailer
```

### Uninstall the Service
```powershell
pwsh .\deploy\UninstallTask.ps1
```

### Complete Cleanup
```powershell
pwsh .\deploy\Cleanup.ps1
```

## Configuration Files

- `config\config.json` - Main configuration (schedule, SMTP, Checkmarx settings)
- `config\recipients.txt` - Email recipient list (one per line)
- `logs\service.log` - Service activity log

## Security Notes

- Credentials are encrypted using Windows DPAPI with machine-level protection
- Only users on this specific machine can decrypt the credentials
- The service runs under the SYSTEM account with highest privileges
- Ensure your `config\recipients.txt` only contains authorized email addresses
