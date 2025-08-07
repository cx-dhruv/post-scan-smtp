# SecureConfig.psm1
# This module provides functions to securely store and retrieve secrets using Windows

function Set-SecureSecret {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Secret
    )
    if (-not $Secret) {
        Write-Host "Error: Secret for key $Key is empty or null."
        throw "Secret for key $Key cannot be empty."
    }

    $secureSecret = $Secret | ConvertTo-SecureString -AsPlainText -Force
    $credential = New-Object PSCredential ($Key, $secureSecret)
    $filePath = "$env:APPDATA\SecureSecrets\$Key.cred"

    if (-not (Test-Path "$env:APPDATA\SecureSecrets")) {
        New-Item -ItemType Directory -Path "$env:APPDATA\SecureSecrets" | Out-Null
    }

    $credential | Export-CliXml -Path $filePath -Force
    Write-Host "Secret stored successfully for key: $Key"
}

function Get-SecureSecret {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$Key
    )
    $filePath = "$env:APPDATA\SecureSecrets\$Key.cred"

    if (-not (Test-Path $filePath)) {
        Write-Host "Error: Secret $Key not found."
        throw "Secret $Key not found. Ensure the credential is stored correctly using Set-SecureSecret."
    }

    $credential = Import-CliXml -Path $filePath
    $credential.GetNetworkCredential().Password
}

function Use-EnvFile {
    param([string]$FilePath = "$PSScriptRoot\..\.env")

    if (-not (Test-Path $FilePath)) {
        Write-Log "Error: .env file not found at $FilePath"
        throw "Error: .env file not found at $FilePath"
    }

    Get-Content $FilePath | ForEach-Object {
        if ($_ -match "^\s*([^#][^=]+)=(.+)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
}

Export-ModuleMember -Function *-SecureSecret, Use-EnvFile
