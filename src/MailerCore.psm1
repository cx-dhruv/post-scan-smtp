using namespace System.Web

# Embed SecureConfig functions directly to avoid module loading issues
$script:SecretBasePath = "$env:ProgramData\CxMailer\Secrets"

function Get-SecureSecret {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$Key
    )
    
    $filePath = "$script:SecretBasePath\$Key.txt"

    if (-not (Test-Path $filePath)) {
        Write-Log "Error: Secret $Key not found at $filePath"
        throw "Secret $Key not found. Ensure the credential is stored correctly using Set-SecureSecret."
    }

    try {
        # Read encrypted string from file
        $encryptedString = Get-Content -Path $filePath -Raw
        
        # Convert back to secure string using machine key, then to plain text
        $secureString = ConvertTo-SecureString -String $encryptedString -Key (Get-MachineKey)
        $credential = New-Object System.Management.Automation.PSCredential ("dummy", $secureString)
        
        return $credential.GetNetworkCredential().Password
    }
    catch {
        Write-Log "Error reading secret ${Key}: $($_.Exception.Message)"
        throw
    }
}

function Get-MachineKey {
    # Generate a consistent key based on machine-specific information
    # This allows any user on this machine to encrypt/decrypt
    $machineGuid = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name MachineGuid).MachineGuid
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($machineGuid)
    
    # Create a 256-bit key (32 bytes) from the machine GUID
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hash = $sha256.ComputeHash($bytes)
    $sha256.Dispose()
    
    return $hash
}

function Use-EnvFile {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        Write-Log "Info: .env file not found at $FilePath"
        return
    }

    Get-Content $FilePath | ForEach-Object {
        if ($_ -match "^\s*([^#][^=]+)=(.+)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
}

# Globals for token caching
$Global:CxAccessToken = $null
$Global:CxTokenFetchedAt = $null

function Write-Log {
    param(
        [string]$Message,
        [string]$LogFile = "$PSScriptRoot\..\logs\service.log"
    )
    if (-not (Test-Path (Split-Path $LogFile -Parent))) { New-Item -ItemType Directory -Path (Split-Path $LogFile -Parent) -Force | Out-Null }
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$timestamp - $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
}

function Get-LastProcessedTimestamp {
    $stateFile = "$env:ProgramData\CxMailer\last_processed.txt"
    if (Test-Path $stateFile -PathType Leaf) {
        try {
            $rawTs = (Get-Content -Path $stateFile -Raw).Trim()
            if ([string]::IsNullOrWhiteSpace($rawTs)) { throw "empty" }
            $parsed = [DateTime]::ParseExact($rawTs, "yyyy-MM-ddTHH:mm:ss.ffffffZ", $null)
            $lastProcessed = [DateTime]::SpecifyKind($parsed, [DateTimeKind]::Utc)

            Write-Log "Last processed timestamp (stored UTC): $($lastProcessed.ToString('yyyy-MM-ddTHH:mm:ss.ffffffZ'))"
            Write-Log "Last processed timestamp (local): $($lastProcessed.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss'))"

            if ($lastProcessed -gt [DateTime]::UtcNow) {
                Write-Log "Warning: Stored timestamp is ahead of current time. Resetting to current UTC.";
                $lastProcessed = [DateTime]::UtcNow
                Set-LastProcessedTimestamp $lastProcessed
            }
            return $lastProcessed
        }
        catch {
            Write-Log "Warning: Invalid timestamp format in state file (will use fallback). Error: $($_.Exception.Message)"
        }
    }

    $fallback = ([DateTime]::UtcNow).AddDays(-1)
    Write-Log "Using fallback last-processed timestamp (UTC): $($fallback.ToString('yyyy-MM-ddTHH:mm:ss.ffffffZ')) - persisting it for future runs"
    Set-LastProcessedTimestamp $fallback
    return $fallback
}

function Set-LastProcessedTimestamp {
    param([DateTime]$Time)
    $stateDir = "$env:ProgramData\CxMailer"
    $stateFile = "$stateDir\last_processed.txt"
    if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }

    $utcTime = if ($Time.Kind -ne [DateTimeKind]::Utc) { $Time.ToUniversalTime() } else { $Time }
    $utcTime.ToString("yyyy-MM-ddTHH:mm:ss.ffffffZ") | Out-File -FilePath $stateFile -Encoding utf8 -Force

    Write-Log "Saved last processed timestamp (UTC): $($utcTime.ToString('yyyy-MM-ddTHH:mm:ss.ffffffZ'))"
    Write-Log "Saved last processed timestamp (local): $($utcTime.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss'))"
}

# --- New Scan ID Tracking Functions ---
function Get-SeenScanIds {
    $seenFile = "$env:ProgramData\CxMailer\seen_scans.txt"
    if (Test-Path $seenFile -PathType Leaf) {
        try {
            $content = Get-Content -Path $seenFile -Raw
            if ([string]::IsNullOrWhiteSpace($content)) {
                Write-Log "Seen scans file is empty, returning empty set"
                return @{}
            }
            $seenIds = @{}
            $content -split "`r?`n" | Where-Object { $_ -ne "" } | ForEach-Object {
                $seenIds[$_.Trim()] = $true
            }
            Write-Log "Loaded $($seenIds.Count) seen scan IDs from file"
            return $seenIds
        }
        catch {
            Write-Log "Warning: Error reading seen scans file. Error: $($_.Exception.Message)"
            return @{}
        }
    }
    Write-Log "No seen scans file found, returning empty set"
    return @{}
}

function Add-SeenScanId {
    param([string]$ScanId)
    $seenDir = "$env:ProgramData\CxMailer"
    $seenFile = "$seenDir\seen_scans.txt"
    if (-not (Test-Path $seenDir)) { New-Item -ItemType Directory -Path $seenDir -Force | Out-Null }
    $ScanId | Out-File -FilePath $seenFile -Append -Encoding utf8
    Write-Log "Added scan ID $ScanId to seen list"
}

function Test-ScanIdSeen {
    param(
        [string]$ScanId,
        [hashtable]$SeenIds
    )
    return $SeenIds.ContainsKey($ScanId)
}

# function Janitor {
#     param(
#         [int]$DaysToKeep = 30
#     )
#     $seenFile = "$env:ProgramData\CxMailer\seen_scans.txt"
#     if (-not (Test-Path $seenFile -PathType Leaf)) { return }
#     try {
#         $cutoff = (Get-Date).AddDays(-$DaysToKeep)
#         $lines = Get-Content -Path $seenFile
#         $newLines = @()
#         foreach ($line in $lines) {
#             if ([string]::IsNullOrWhiteSpace($line)) { continue }
#             $parts = $line -split '\|'
#             if ($parts.Count -lt 2) { continue } # skip malformed
#             $date = $null
#             if ([DateTime]::TryParse($parts[1], [ref]$date)) {
#                 if ($date -ge $cutoff) {
#                     $newLines += $line
#                 }
#             }
#         }
#         $newLines | Out-File -FilePath $seenFile -Encoding utf8 -Force
#         Write-Log "Cleanup complete. Kept $($newLines.Count) scan IDs newer than $DaysToKeep days"
#     }
#     catch {
#         Write-Log "Error during cleanup of seen scan IDs: $($_.Exception.Message)"
#     }
# }

# --- End New Functions ---

function New-CxAccessToken {
    param($Config)
    if ($Global:CxAccessToken -and $Global:CxTokenFetchedAt -and ((Get-Date) - $Global:CxTokenFetchedAt).TotalMinutes -lt 29) {
        Write-Log "Reusing cached access token."
        return $Global:CxAccessToken
    }
    Write-Log "Requesting new access token for tenant: $($Config.cxOne.tenant)"
    $body = @{
        client_id     = (Get-SecureSecret "$($Config.cxOne.tenant)-clientId")
        client_secret = (Get-SecureSecret "$($Config.cxOne.tenant)-clientSecret")
        grant_type    = "client_credentials"
    }
    $uri = "https://$($Config.cxOne.region).iam.checkmarx.net/auth/realms/$($Config.cxOne.tenant)/protocol/openid-connect/token"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
        if (-not $response.access_token) { throw "No access_token in token response" }
        $Global:CxAccessToken = $response.access_token
        $Global:CxTokenFetchedAt = Get-Date
        Write-Log "Access token retrieved successfully at $($Global:CxTokenFetchedAt.ToString('yyyy-MM-dd HH:mm:ss'))"
        return $Global:CxAccessToken
    }
    catch {
        Write-Log "Failed to retrieve access token. Error: $($_.Exception.Message)"
        throw
    }
}

function Get-CxCompletedScans {
    param($Config, $Token, [DateTime]$FromDate)
    Write-Log "Queried API is called."
    $headers = @{ Authorization = "Bearer $Token"; Accept = "application/json; version=1.0" }
    $statuses = "Failed,Completed,Partial"
    if (-not $FromDate) { $FromDate = ([DateTime]::UtcNow).AddDays(-1) }
    if ($FromDate.Kind -ne [DateTimeKind]::Utc) { $FromDate = $FromDate.ToUniversalTime() }
    $fromDateStr = $FromDate.ToString("yyyy-MM-ddTHH:mm:ss.ffffffZ")
    $queryString = "statuses=$statuses&from-date=$fromDateStr"
    $uri = "https://$($Config.cxOne.region).ast.checkmarx.net/api/scans?$queryString"
    try {
        Write-Log "DEBUG: API call using from-date (UTC): $fromDateStr"
        Write-Log "DEBUG: full URI = $uri"
        $raw = Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 30
        if ($null -eq $raw) { return @() }
        if ($raw -is [array]) { $scans = $raw }
        elseif ($raw.scans -is [array]) { $scans = $raw.scans }
        else { $scans = @() }
        Write-Log "List of completed scans fetched successfully. Count: $($scans.Count)"
        return $scans
    }
    catch {
        Write-Log "Failed to fetch list of scans. Error: $($_.Exception.Message)"
        throw
    }
}

function Get-CxScanDetails {
    param($Config, $Token, $ScanId)
    Write-Log "Fetching scan details for Scan ID: $ScanId."
    $headers = @{ Authorization = "Bearer $Token"; Accept = "application/json; version=1.0" }
    $uri = "https://$($Config.cxOne.region).ast.checkmarx.net/api/scans/$ScanId"
    try {
        $details = Invoke-RestMethod -Uri $uri -Headers $headers
        Write-Log "Scan details fetched successfully for $ScanId"
        return $details
    }
    catch {
        Write-Log "Failed to fetch scan details for $ScanId. Error: $($_.Exception.Message)"
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
    try {
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
    }
    catch {
        Write-Log "Failed to send email: $($_.Exception.Message)"
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
    return $template
}

function Invoke-Mailer {
    param($Config)
    Write-Log "Starting mailer invocation."
    $token = New-CxAccessToken $Config
    #Janitor -DaysToKeep 7
    $seenScanIds = Get-SeenScanIds
    if (-not $script:StableFromDate) {
        $script:StableFromDate = Get-LastProcessedTimestamp
    }
    $fromDateUtc = $script:StableFromDate
    Write-Log "Using from-date (UTC): $($fromDateUtc.ToString('yyyy-MM-ddTHH:mm:ss.ffffffZ'))"
    Write-Log "Using from-date (Local): $($fromDateUtc.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss'))"
    $scans = Get-CxCompletedScans $Config $token $fromDateUtc
    $scanCount = $scans.Count
    Write-Log "Scans fetched successfully. Count: $scanCount"
    if ($scanCount -eq 0) {
        Write-Log "No scans found from API. Timestamp will remain unchanged."
        return
    }
    $processed = @()
    $skippedCount = 0
    foreach ($scan in $scans) {
        try {
            if (Test-ScanIdSeen -ScanId $scan.id -SeenIds $seenScanIds) {
                Write-Log "Skipping Scan ID: $($scan.id) - already processed"
                $skippedCount++
                continue
            }
            Write-Log "Processing Scan ID: $($scan.id)"
            $details = Get-CxScanDetails $Config $token $scan.id
            $localNow = (Get-Date).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")
            $body = Get-EncodedTemplate "$PSScriptRoot\..\templates\notification_template.html" @{
                Project   = $details.projectName
                Status    = $scan.status
                RiskScore = $details.riskScore
                Summary   = ($details.statistics | ConvertTo-Json -Compress)
                TimeUtc   = $localNow
            }
            Send-SecureMail $Config "Checkmarx scan $($scan.id) completed" $body
            Add-SeenScanId -ScanId $scan.id
            $seenScanIds[$scan.id] = $true
            $processed += $scan
            Write-Log "Scan ID: $($scan.id) processed successfully."
        }
        catch {
            Write-Log "Error processing Scan ID: $($scan.id). Error: $($_.Exception.Message)"
        }
    }
    Write-Log "Processed $($processed.Count) new scans, skipped $skippedCount already seen scans"
    if ($scans.Count -gt 0) {
        $latestDate = $scans | ForEach-Object {
            if ($_.finishedOn) { [DateTime]$_.finishedOn }
            elseif ($_.created) { [DateTime]$_.created }
            elseif ($_.date) { [DateTime]$_.date }
        } | Where-Object { $_ -ne $null } | Sort-Object -Descending | Select-Object -First 1
        if (-not $latestDate) { $latestDate = [DateTime]::UtcNow }
        $utcToSave = if ($latestDate.Kind -ne [DateTimeKind]::Utc) { $latestDate.ToUniversalTime() } else { $latestDate }
        if ($utcToSave -gt [DateTime]::UtcNow) { $utcToSave = [DateTime]::UtcNow }
        Write-Log "Latest scan time (UTC to save): $($utcToSave.ToString('yyyy-MM-ddTHH:mm:ss.ffffffZ'))"
        Write-Log "Latest scan time (local): $($utcToSave.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss'))"
        $script:StableFromDate = $utcToSave
        Set-LastProcessedTimestamp $utcToSave
    }
    Write-Log "Mailer invocation completed."
}

Export-ModuleMember -Function Invoke-Mailer
