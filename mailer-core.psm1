function Get-AccessToken {
    param ($Config)
    $uri = "https://$($Config.cxOne.region).iam.checkmarx.net/auth/realms/$($Config.cxOne.tenant)/protocol/openid-connect/token"
    $body = @{
        client_id     = $Config.cxOne.clientId
        client_secret = $Config.cxOne.clientSecret
        grant_type    = "client_credentials"
    }

    $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
    return $response.access_token
}

function Get-CompletedScans {
    param ($Config, $Token)
    $headers = @{
        Authorization = "Bearer $Token"
        Accept        = "application/json; version=1.0"
    }

    $uri = "https://$($Config.cxOne.region).ast.checkmarx.net/api/scans?limit=1000"
    $scans = (Invoke-RestMethod -Uri $uri -Headers $headers -Method Get).scans

    $completed = @()
    foreach ($scan in $scans) {
        if ($scan.status -in @("Completed", "Partial", "Failed") -and -not (Test-Path ".scans\$($scan.id).done")) {
            $completed += $scan
        }
    }
    return $completed
}

function Get-ScanDetails {
    param ($Config, $Token, $ScanId)
    $headers = @{
        Authorization = "Bearer $Token"
        Accept        = "application/json; version=1.0"
    }
    $uri = "https://$($Config.cxOne.region).ast.checkmarx.net/api/scans/$ScanId"
    return Invoke-RestMethod -Uri $uri -Headers $headers
}

function Get-ScanSummary {
    param ($Config, $Token, $ScanId)
    $headers = @{
        Authorization = "Bearer $Token"
        Accept        = "application/json; version=1.0"
    }
    $uri = "https://$($Config.cxOne.region).ast.checkmarx.net/api/scan-summary/$ScanId"
    return Invoke-RestMethod -Uri $uri -Headers $headers
}

function Format-ScanSummary {
    param ($Scan, $Details, $Summary)
    return @"
<h3>Scan ID: $($Scan.id)</h3>
<ul>
  <li><strong>Project:</strong> $($Scan.projectName)</li>
  <li><strong>Branch:</strong> $($Details.branch)</li>
  <li><strong>Initiator:</strong> $($Scan.initiator)</li>
  <li><strong>User Agent:</strong> $($Scan.userAgent)</li>
  <li><strong>Status:</strong> $($Scan.status)</li>
  <li><strong>Score:</strong> $($Summary.totalScore)</li>
  <li><strong>Started:</strong> $($Scan.startTime)</li>
  <li><strong>Completed:</strong> $($Scan.endTime)</li>
</ul>
"@
}

function Send-Email {
    param (
        [string]$Body,
        [hashtable]$SmtpConfig
    )

    $client = New-Object System.Net.Mail.SmtpClient($SmtpConfig.server, $SmtpConfig.port)
    $client.EnableSsl = $true
    $client.Credentials = New-Object System.Net.NetworkCredential($SmtpConfig.username, $SmtpConfig.password)

    $mail = New-Object System.Net.Mail.MailMessage
    $mail.From = $SmtpConfig.from
    foreach ($recipient in $SmtpConfig.to) {
        $mail.To.Add($recipient)
    }
    $mail.Subject = "Checkmarx Scan Report"
    $mail.Body = $Body
    $mail.IsBodyHtml = $true

    $client.Send($mail)
    Log-Activity -Message "Sent email to $($SmtpConfig.to -join ', ')"
}

function Log-Activity {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = "$PSScriptRoot\logs\service.log"

    if (-not (Test-Path "$PSScriptRoot\logs")) {
        New-Item -ItemType Directory -Path "$PSScriptRoot\logs" | Out-Null
    }

    $logMessage = "[{0}] {1}" -f $timestamp, $Message
    Add-Content -Path $logFile -Value $logMessage
}



function Invoke-Mailer {
    $Config = Get-Content -Raw -Path "./config.json" | ConvertFrom-Json
    $Token = Get-AccessToken -Config $Config
    $Scans = Get-CompletedScans -Config $Config -Token $Token

    foreach ($scan in $Scans) {
        $details = Get-ScanDetails -Config $Config -Token $Token -ScanId $scan.id
        $summary = Get-ScanSummary -Config $Config -Token $Token -ScanId $scan.id

        $scanHtml = Format-ScanSummary -Scan $scan -Details $details -Summary $summary
        $template = Get-Content -Raw -Path "./template.html"
        $finalBody = $template -replace "{{SCAN_SUMMARY}}", $scanHtml

        Send-Email -Body $finalBody -SmtpConfig $Config.smtp
        New-Item -ItemType File -Path ".scans\$($scan.id).done" -Force | Out-Null
    }
}

Export-ModuleMember -Function *
