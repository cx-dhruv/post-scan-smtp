using namespace System.Web
Import-Module "$PSScriptRoot\..\config\SecureConfig.psm1" -Force

function Write-Log {
    param(
        [string]$Message,
        [string]$LogFile = "$PSScriptRoot\..\logs\service.log"
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$timestamp - $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
}

function Get-LastProcessedTimestamp {
    $stateFile = "$env:ProgramData\CxMailer\last_processed.txt"
    if (Test-Path $stateFile -PathType Leaf) {
        try {
            return [DateTime]::ParseExact((Get-Content -Path $stateFile -Raw).Trim(), "yyyy-MM-ddTHH:mm:ss.ffffffZ", $null)
        }
        catch {
            Write-Log "Warning: Invalid timestamp format in state file. Defaulting to 7 days ago."
        }
    }
    return (Get-Date).AddDays(-7)
}

function Set-LastProcessedTimestamp {
    param([DateTime]$Time)
    $stateDir  = "$env:ProgramData\CxMailer"
    $stateFile = "$stateDir\last_processed.txt"
    if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
    $Time.ToString("yyyy-MM-ddTHH:mm:ss.ffffffZ") | Out-File -FilePath $stateFile -Encoding utf8 -Force
}
# ======================

function New-CxAccessToken {
    param($Config)
    Write-Log "Requesting new access token for tenant: $($Config.cxOne.tenant)"
    $body = @{
        client_id     = (Get-SecureSecret "$($Config.cxOne.tenant)-clientId")
        client_secret = (Get-SecureSecret "$($Config.cxOne.tenant)-clientSecret")
        grant_type    = "client_credentials"
    }
    $uri = "https://$($Config.cxOne.region).iam.checkmarx.net/auth/realms/$($Config.cxOne.tenant)/protocol/openid-connect/token"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
        Write-Log "Access token retrieved successfully"
        $response.access_token
    }
    catch {
        Write-Log "Failed to retrieve access token. Error: $_.Exception.Message"
        Write-Log "Stack Trace: $_.Exception.StackTrace"
        throw
    }
}

function Get-CxCompletedScans {
    param($Config, $Token, [DateTime]$FromDate)
    Write-Log "Fetching list of completed scans with query parameters."
    $headers = @{Authorization = "Bearer $Token"; Accept = "application/json; version=1.0" }
    
    $statuses = "Failed,Completed,Partial"
    if (-not $FromDate) { $FromDate = (Get-Date).AddDays(-1) }
    
    $queryParams = @{
        statuses    = $statuses
        'from-date' = $FromDate.ToString("yyyy-MM-ddTHH:mm:ss.ffffffZ")
    }

    $baseUri = "https://$($Config.cxOne.region).ast.checkmarx.net/api/scans/"
    $uri = $baseUri + "?" + (
        $queryParams.GetEnumerator() |
        ForEach-Object { "$($_.Key)=$([System.Web.HttpUtility]::UrlEncode($_.Value))" } |
        Join-String -Separator "&"
    )

    try {
        $scans = Invoke-RestMethod -Uri $uri -Headers $headers
        Write-Log "List of completed scans fetched successfully using query parameters"
        return $scans.scans
    }
    catch {
        Write-Log "Failed to fetch list of scans. Error: $_.Exception.Message"
        Write-Log "Stack Trace: $_.Exception.StackTrace"
        throw
    }
}

function Send-SecureMail {
    param($Config, $Subject, $BodyHtml)
    Write-Log "Sending email with subject: $Subject"

    $smtpServer = (Get-SecureSecret "smtp-server")
    if (-not $smtpServer) {
        Write-Log "Error: SMTP server is not configured."
        throw "SMTP server is not configured."
    }

    $smtpCred = New-Object PSCredential (
        (Get-SecureSecret "smtp-username"),
        (Get-SecureSecret "smtp-password" | ConvertTo-SecureString -AsPlainText -Force)
    )

    try {
        Send-MailMessage -SmtpServer $smtpServer `
            -Port $Config.smtp.port `
            -UseSsl `
            -Credential $smtpCred `
            -From $Config.smtp.from `
            -To (Get-Content "$PSScriptRoot\..\config\recipients.txt") `
            -Subject $Subject `
            -BodyAsHtml $BodyHtml -Encoding UTF8
        Write-Log "Email sent successfully."
    }
    catch {
        Write-Log "Failed to send email: $_.Exception.Message"
        Write-Log "Stack Trace: $_.Exception.StackTrace"
        throw
    }
}

function Get-EncodedTemplate {
    param($Path, $Map)
    $template = Get-Content -Raw -Path $Path
    foreach ($k in $Map.Keys) {
        $val = [HttpUtility]::HtmlEncode($Map[$k])
        $template = $template -replace "\{\{$k\}\}", $val
    }
    $template
}

function Get-CxScanDetails {
    param($Config, $Token, $ScanId)
    Write-Log "Fetching scan details for Scan ID: $ScanId."
    $headers = @{Authorization = "Bearer $Token"; Accept = "application/json; version=1.0" }
    $uri = "https://$($Config.cxOne.region).ast.checkmarx.net/api/scans/$ScanId"
    try {
        $details = Invoke-RestMethod -Uri $uri -Headers $headers
        Write-Log "Scan details fetched successfully"
        $details
    }
    catch {
        Write-Log "Failed to fetch scan details. Error: $_.Exception.Message"
        Write-Log "Stack Trace: $_.Exception.StackTrace"
        throw
    }
}

function Invoke-Mailer {
    param($Config)
    Write-Log "Starting mailer invocation."

    # Obtain access token
    $token = New-CxAccessToken $Config

    # Determine the starting point for the query
    $fromDate = Get-LastProcessedTimestamp
    Write-Log "Last processed timestamp: $fromDate"

    # Fetch only the scans that are newer than the last processed timestamp
    $scans = Get-CxCompletedScans $Config $token $fromDate

    $processed = @()
    foreach ($scan in $scans) {
        try {
            Write-Log "Processing Scan ID: $($scan.id)"
            $details = Get-CxScanDetails $Config $token $scan.id
            Write-Log "risk score: $($details.riskScore)"
            Write-Log "Scan Summary: $($details.statistics | ConvertTo-Json -Compress)"

            $body = Get-EncodedTemplate "$PSScriptRoot\..\templates\notification_template.html" @{
                Project   = $details.projectName
                Status    = $scan.status
                RiskScore = $details.riskScore
                Summary   = ($details.statistics | ConvertTo-Json -Compress)
                TimeUtc   = (Get-Date).ToUniversalTime().ToString("u")
            }

            Send-SecureMail $Config "Checkmarx scan $($scan.id) completed" $body
            
            # Optional legacy marker file (kept for backwards-compat)
            New-Item -ItemType File -Path "$env:ProgramData\CxMailer\.done\$($scan.id)" -Force | Out-Null

            $processed += $scan
            Write-Log "Scan ID: $($scan.id) processed successfully."
        }
        catch {
            Write-Log "Error processing Scan ID: $($scan.id). Error: $_.Exception.Message"
            Write-Log "Stack Trace: $_.Exception.StackTrace"
        }
    }

    # Update the last-processed timestamp only if we handled scans successfully
    if ($processed.Count -gt 0) {
        $latestDate = $null
        foreach ($scan in $processed) {
            $candidate = $null
            if ($scan.finishedOn)      { $candidate = [datetime]$scan.finishedOn }
            elseif ($scan.created)     { $candidate = [datetime]$scan.created }
            elseif ($scan.date)        { $candidate = [datetime]$scan.date }
            if ($candidate -and (-not $latestDate -or $candidate -gt $latestDate)) {
                $latestDate = $candidate
            }
        }
        if (-not $latestDate) { $latestDate = Get-Date }
        Set-LastProcessedTimestamp $latestDate
        Write-Log "Updated last processed timestamp to $latestDate"
    }

    Write-Log "Mailer invocation completed."
}
Export-ModuleMember -Function Invoke-Mailer
