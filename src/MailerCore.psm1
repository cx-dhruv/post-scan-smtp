using namespace System.Web
Import-Module "$PSScriptRoot\..\config\SecureConfig.psm1" -Force

function New-CxAccessToken {
    param($Config)
    $body = @{
        client_id     = (Get-SecureSecret "$($Config.cxOne.tenant)-clientId")
        client_secret = (Get-SecureSecret "$($Config.cxOne.tenant)-clientSecret")
        grant_type    = "client_credentials"
    }
    $uri = "https://$($Config.cxOne.region).iam.checkmarx.net/auth/realms/$($Config.cxOne.tenant)/protocol/openid-connect/token"
    (Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/x-www-form-urlencoded").access_token
}

function Get-CxCompletedScans {
    param($Config,$Token)
    $headers = @{Authorization = "Bearer $Token"; Accept = "application/json; version=1.0"}
    $uri  = "https://$($Config.cxOne.region).ast.checkmarx.net/api/scans?limit=1000"
    (Invoke-RestMethod -Uri $uri -Headers $headers).scans |
        Where-Object { $_.status -in "Completed","Partial","Failed" }
}

function Send-SecureMail {
    param($Config,$Subject,$BodyHtml)
    $smtpCred = New-Object PSCredential (
        (Get-SecureSecret "smtp-username"),
        (ConvertTo-SecureString (Get-SecureSecret "smtp-password") -AsPlainText -Force)
    )
    Send-MailMessage -SmtpServer $Config.smtp.server `
                     -Port $Config.smtp.port `
                     -UseSsl `
                     -Credential $smtpCred `
                     -From $Config.smtp.from `
                     -To (Get-Content "$PSScriptRoot\..\config\recipients.txt") `
                     -Subject $Subject `
                     -BodyAsHtml $BodyHtml -Encoding UTF8
}

function Get-EncodedTemplate {
    param($Path,$Map)
    $template = Get-Content -Raw -Path $Path
    foreach ($k in $Map.Keys) {
        $val = [HttpUtility]::HtmlEncode($Map[$k])
        $template = $template -replace "\{\{$k\}\}", $val
    }
    $template
}

function Invoke-Mailer {
    param($Config)
    $token   = New-CxAccessToken $Config
    $scans   = Get-CxCompletedScans $Config $token
    foreach ($scan in $scans) {
        $details = Get-CxScanDetails $Config $token $scan.id
        $summary = Get-CxScanSummary $Config $token $scan.id
        $body    = Get-EncodedTemplate "$PSScriptRoot\..\templates\notification_template.html" @{
            Project   = $details.projectName
            Status    = $scan.status
            RiskScore = $summary.riskScore
            Summary   = ($summary.statistics | ConvertTo-Json -Compress)
            ScanLink  = "https://$($Config.cxOne.region).ast.checkmarx.net/projects/$($details.projectId)/scans/$($scan.id)"
            TimeUtc   = (Get-Date).ToUniversalTime().ToString("u")
        }
        Send-SecureMail $Config "Checkmarx scan $($scan.id) completed" $body
        New-Item -ItemType File -Path "$env:ProgramData\CxMailer\.done\$($scan.id)" -Force | Out-Null
    }
}
Export-ModuleMember -Function Invoke-Mailer
