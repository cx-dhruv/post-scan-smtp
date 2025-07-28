# SecureConfig.psm1
# This module provides functions to securely store and retrieve secrets using Windows

function Set-SecureSecret {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Secret
    )
    cmd /c "cmdkey /generic:$Key /user:$Key /pass:$Secret"
}

function Get-SecureSecret {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$Key
    )
    Write-Host "Attempting to retrieve secret for key: $Key"
    $creds = cmd /c "cmdkey /list:$Key" 2>$null
    if ($LASTEXITCODE) {
        Write-Host "Error: Secret $Key not found. Command output: $creds"
        throw "Secret $Key not found"
    }

    $passwordLine = $creds -split "`r?`n" | Where-Object { $_ -match "Password:" }
    if (-not $passwordLine) {
        Write-Host "Error: Password line not found for key $Key. Command output: $creds"
        throw "Password not found for key $Key"
    }

    $password = ($passwordLine -split "Password:")[1].Trim()
    Write-Host "Secret retrieved successfully for key: $Key"
    return $password
}

Export-ModuleMember -Function *-SecureSecret
