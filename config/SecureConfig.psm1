# SecureConfig.psm1
# This module provides functions to securely store and retrieve secrets using Windows DPAPI

# Use ProgramData for system-wide access
$script:SecretBasePath = "$env:ProgramData\CxMailer\Secrets"

function Set-SecureSecret {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Secret
    )
    
    if (-not $Secret) {
        Write-Host "Error: Secret for key $Key is empty or null."
        throw "Secret for key $Key cannot be empty."
    }

    # Ensure the secrets directory exists
    if (-not (Test-Path $script:SecretBasePath)) {
        New-Item -ItemType Directory -Path $script:SecretBasePath -Force | Out-Null
    }

    $filePath = "$script:SecretBasePath\$Key.txt"
    
    try {
        # Convert secret to secure string and then to encrypted standard string
        # Using LocalMachine scope so any user (including SYSTEM) can decrypt
        $secureString = ConvertTo-SecureString -String $Secret -AsPlainText -Force
        $encryptedString = ConvertFrom-SecureString -SecureString $secureString -Key (Get-MachineKey)
        
        # Save encrypted string to file
        $encryptedString | Out-File -FilePath $filePath -Force
        
        Write-Host "Secret stored successfully for key: $Key"
    }
    catch {
        Write-Host "Error storing secret: $($_.Exception.Message)"
        throw
    }
}

function Get-SecureSecret {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$Key
    )
    
    $filePath = "$script:SecretBasePath\$Key.txt"

    if (-not (Test-Path $filePath)) {
        Write-Host "Error: Secret $Key not found at $filePath"
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
        Write-Host "Error reading secret ${Key}: $($_.Exception.Message)"
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
    param([string]$FilePath = "$PSScriptRoot\..\.env")

    if (-not (Test-Path $FilePath)) {
        Write-Host "Info: .env file not found at $FilePath"
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

# Function to test if secrets are accessible
function Test-SecureSecrets {
    [CmdletBinding()] param()
    
    Write-Host "`nTesting secret storage accessibility..."
    Write-Host "Current user: $env:USERNAME"
    Write-Host "Secret base path: $script:SecretBasePath"
    
    if (Test-Path $script:SecretBasePath) {
        $files = Get-ChildItem -Path $script:SecretBasePath -Filter "*.txt" -ErrorAction SilentlyContinue
        if ($files) {
            Write-Host "Found $($files.Count) stored secrets"
            foreach ($file in $files) {
                $keyName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                try {
                    $null = Get-SecureSecret -Key $keyName
                    Write-Host "  ✓ $keyName - accessible"
                }
                catch {
                    Write-Host "  ✗ $keyName - not accessible: $($_.Exception.Message)"
                }
            }
        }
        else {
            Write-Host "No secrets found in storage"
        }
    }
    else {
        Write-Host "Secret storage directory does not exist"
    }
}

Export-ModuleMember -Function *-SecureSecret, Use-EnvFile, Test-SecureSecrets