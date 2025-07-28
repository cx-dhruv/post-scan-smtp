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
    $creds = cmd /c "cmdkey /list:$Key" 2>$null
    if ($LASTEXITCODE) { throw "Secret $Key not found" }

    $passwordLine = $creds -split "`r?`n" | Where-Object { $_ -match "Password:" }
    if (-not $passwordLine) { throw "Password not found for key $Key" }

    return ($passwordLine -split "Password:")[1].Trim()
}

Export-ModuleMember -Function *-SecureSecret
