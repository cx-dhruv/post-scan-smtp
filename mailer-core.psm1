function Invoke-ApiCalls {
    param ([array]$Apis)

    $results = @()
    foreach ($api in $Apis) {
        try {
            Write-Host "Calling $($api.name)..."
            $response = Invoke-RestMethod -Uri $api.url -Headers $api.headers -Method GET -ErrorAction Stop
            $results += @{
                name = $api.name
                response = $response
            }
        } catch {
            $results += @{
                name = $api.name
                response = "ERROR: $_"
            }
        }
    }
    return $results
}

function Format-EmailBody {
    param ([array]$ApiResponses)

    $body = "<html><body><h2>API Report</h2>"
    foreach ($item in $ApiResponses) {
        $body += "<h3>$($item.name)</h3><pre>$($item.response | Out-String)</pre>"
    }
    $body += "</body></html>"
    return $body
}

function Send-Email {
    param (
        [string]$Body,
        [hashtable]$SmtpConfig
    )

    try {
        $smtpClient = New-Object System.Net.Mail.SmtpClient($SmtpConfig.server, $SmtpConfig.port)
        $smtpClient.EnableSsl = $true
        $smtpClient.Credentials = New-Object System.Net.NetworkCredential($SmtpConfig.username, $SmtpConfig.password)

        $mail = New-Object System.Net.Mail.MailMessage
        $mail.From = $SmtpConfig.from
        foreach ($to in $SmtpConfig.to) {
            $mail.To.Add($to)
        }
        $mail.Subject = "Automated API Report"
        $mail.Body = $Body
        $mail.IsBodyHtml = $true

        $smtpClient.Send($mail)
        Write-Output "Email sent successfully."
    } catch {
        Write-Output "Failed to send email: $_"
    }
}

function Log-Activity {
    param (
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] $Message"
    Add-Content -Path "./logs/service.log" -Value $logLine
}

function Invoke-Mailer {
    $config = Get-Content -Raw -Path "./config.json" | ConvertFrom-Json
    $responses = Invoke-ApiCalls -Apis $config.apis
    $body = Format-EmailBody -ApiResponses $responses
    Send-Email -Body $body -SmtpConfig $config.smtp
    Log-Activity "Mailer run completed."
}
