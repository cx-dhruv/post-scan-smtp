# Test script that captures the exact HTML being sent

# Temporarily modify Send-SecureMail to save the HTML
$debugCode = @'
function Send-SecureMail {
    param($Config, $Subject, $BodyHtml)
    Write-Log "Sending email with subject: $Subject"
    
    # Save original HTML
    $BodyHtml | Out-File "C:\temp\email_before_embed.html" -Force -Encoding UTF8
    Write-Host "Saved original HTML to C:\temp\email_before_embed.html" -ForegroundColor Yellow
    
    $smtpServer = (Get-SecureSecret "smtp-server")
    if (-not $smtpServer) {
        Write-Log "Error: SMTP server is not configured."
        throw "SMTP server is not configured."
    }
    try {
        # Convert images to base64 for inline embedding
        $adPortsImagePath = "$PSScriptRoot\..\templates\static_assets\AD-Ports-Group.png"
        $checkmarxImagePath = "$PSScriptRoot\..\templates\static_assets\Checkmarx_Logov1.jpg"
        
        Write-Host "AD-Ports path: $adPortsImagePath" -ForegroundColor Cyan
        Write-Host "Checkmarx path: $checkmarxImagePath" -ForegroundColor Cyan
        
        # Read and encode images
        if (Test-Path $adPortsImagePath) {
            $adPortsBytes = [System.IO.File]::ReadAllBytes($adPortsImagePath)
            $adPortsBase64 = [Convert]::ToBase64String($adPortsBytes)
            $adPortsDataUri = "data:image/png;base64,$adPortsBase64"
            
            # Check before replacement
            $hasCid1 = $BodyHtml -match 'src="cid:logo1"'
            Write-Host "Has cid:logo1 before replace: $hasCid1" -ForegroundColor Magenta
            
            $BodyHtml = $BodyHtml -replace 'src="cid:logo1"', "src=`"$adPortsDataUri`""
            Write-Log "Embedded AD-Ports logo"
            Write-Host "Embedded AD-Ports logo (base64 length: $($adPortsBase64.Length))" -ForegroundColor Green
            
            # Check after replacement
            $hasData1 = $BodyHtml -match 'src="data:image/png'
            Write-Host "Has data:image/png after replace: $hasData1" -ForegroundColor Magenta
        } else {
            Write-Log "Warning: AD-Ports logo not found at $adPortsImagePath"
            Write-Host "WARNING: AD-Ports logo not found!" -ForegroundColor Red
        }
        
        if (Test-Path $checkmarxImagePath) {
            $checkmarxBytes = [System.IO.File]::ReadAllBytes($checkmarxImagePath)
            $checkmarxBase64 = [Convert]::ToBase64String($checkmarxBytes)
            $checkmarxDataUri = "data:image/jpeg;base64,$checkmarxBase64"
            
            # Check before replacement
            $hasCid2 = $BodyHtml -match 'src="cid:logo2"'
            Write-Host "Has cid:logo2 before replace: $hasCid2" -ForegroundColor Magenta
            
            $BodyHtml = $BodyHtml -replace 'src="cid:logo2"', "src=`"$checkmarxDataUri`""
            Write-Log "Embedded Checkmarx logo"
            Write-Host "Embedded Checkmarx logo (base64 length: $($checkmarxBase64.Length))" -ForegroundColor Green
            
            # Check after replacement
            $hasData2 = $BodyHtml -match 'src="data:image/jpeg'
            Write-Host "Has data:image/jpeg after replace: $hasData2" -ForegroundColor Magenta
        } else {
            Write-Log "Warning: Checkmarx logo not found at $checkmarxImagePath"
            Write-Host "WARNING: Checkmarx logo not found!" -ForegroundColor Red
        }
        
        # Save modified HTML
        $BodyHtml | Out-File "C:\temp\email_after_embed.html" -Force -Encoding UTF8
        Write-Host "Saved modified HTML to C:\temp\email_after_embed.html" -ForegroundColor Yellow
        
        # Also create a smaller test version with truncated base64
        $testHtml = $BodyHtml -replace '(data:image/[^;]+;base64,)([A-Za-z0-9+/]{100})[A-Za-z0-9+/]+', '$1$2...[TRUNCATED]'
        $testHtml | Out-File "C:\temp\email_preview.html" -Force -Encoding UTF8
        Write-Host "Saved preview HTML to C:\temp\email_preview.html" -ForegroundColor Yellow
        
        $username = Get-SecureSecret "smtp-username"
        $passwordPlain = Get-SecureSecret "smtp-password"
        $securePassword = $passwordPlain | ConvertTo-SecureString -AsPlainText -Force
        $smtpCred = New-Object System.Management.Automation.PSCredential ($username, $securePassword)
        $recipients = Get-Content "$PSScriptRoot\..\config\recipients.txt" -ErrorAction SilentlyContinue
        if (-not $recipients) { Write-Log "Warning: No recipients found in recipients.txt"; $recipients = @() }
        
        Send-MailMessage -SmtpServer $smtpServer `
            -Port $Config.smtp.port `
            -UseSsl `
            -Credential $smtpCred `
            -From $Config.smtp.from `
            -To $recipients `
            -Subject $Subject `
            -BodyAsHtml $BodyHtml -Encoding UTF8
            
        Write-Log "Email sent successfully."
        Write-Host "Email sent with body length: $($BodyHtml.Length) chars" -ForegroundColor Green
    }
    catch {
        Write-Log "Failed to send email: $($_.Exception.Message)"
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}
'@

# Create temp directory
New-Item -ItemType Directory -Path "C:\temp" -Force -ErrorAction SilentlyContinue | Out-Null

# Load the modified function
Invoke-Expression $debugCode

# Import other required functions
Import-Module "$PSScriptRoot\..\config\SecureConfig.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\src\MailerCore.psm1" -Force

# Now run the test
$configPath = "$PSScriptRoot\..\config\config.json"
$config = Get-Content -Raw -Path $configPath | ConvertFrom-Json

$testHtml = Get-EncodedTemplate "$PSScriptRoot\..\templates\notification_template.html" @{
    Project = "Debug Test Project"
    Status = "Completed"
    RiskScore = 99
    Summary = '{"high":1,"medium":2,"low":3,"info":4}'
    TimeUtc = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

Write-Host "`nSending debug test email..." -ForegroundColor Cyan
Send-SecureMail $config "DEBUG TEST: Image Embedding Check" $testHtml

Write-Host "`nDone! Check:" -ForegroundColor Green
Write-Host "  - Your email for the test message" -ForegroundColor Cyan
Write-Host "  - C:\temp\email_before_embed.html (original)" -ForegroundColor Cyan
Write-Host "  - C:\temp\email_after_embed.html (with embedded images)" -ForegroundColor Cyan
Write-Host "  - C:\temp\email_preview.html (preview with truncated base64)" -ForegroundColor Cyan
