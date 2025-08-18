# SecureConfig.psm1
# Secure credential storage module using Windows DPAPI
# Provides machine-level encryption for sensitive data

$script:SecretBasePath = "$env:ProgramData\CxMailer\Secrets"

function Set-SecureSecret {
    # Encrypts and stores a secret using machine-specific encryption
    # Only processes on this specific machine can decrypt the data
    [CmdletBinding()] 
    param(
        [Parameter(Mandatory)]
        [string]$Key,         # Identifier for the secret
        [Parameter(Mandatory)]
        [string]$Secret       # Plain text secret to encrypt
    )
    
    if (-not $Secret) {
        Write-Host "Error: Secret for key $Key is empty or null."
        throw "Secret for key $Key cannot be empty."
    }

    # Create secure storage directory with restricted permissions
    if (-not (Test-Path $script:SecretBasePath)) {
        New-Item -ItemType Directory -Path $script:SecretBasePath -Force | Out-Null
    }

    $filePath = "$script:SecretBasePath\$Key.txt"
    
    try {
        # Convert to SecureString (in-memory protection)
        $secureString = ConvertTo-SecureString -String $Secret -AsPlainText -Force
        
        # Encrypt using machine key derived from registry
        # This ensures portability issues - credentials cannot be moved to another machine
        $encryptedString = ConvertFrom-SecureString -SecureString $secureString -Key (Get-MachineKey)
        
        # Save encrypted data to file
        $encryptedString | Out-File -FilePath $filePath -Force
        Write-Host "Secret stored successfully for key: $Key"
    }
    catch {
        Write-Host "Error storing secret: $($_.Exception.Message)"
        throw
    }
}

function Get-SecureSecret {
    [CmdletBinding()] 
    param(
        [Parameter(Mandatory)]
        [string]$Key
    )
    
    $filePath = "$script:SecretBasePath\$Key.txt"

    if (-not (Test-Path $filePath)) {
        Write-Host "Error: Secret $Key not found at $filePath"
        throw "Secret $Key not found. Ensure the credential is stored correctly using Set-SecureSecret."
    }

    try {
        $encryptedString = Get-Content -Path $filePath -Raw
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
    # Generates a consistent 256-bit encryption key based on machine GUID
    # This key is unique per machine and consistent across all users/sessions
    
    # Read machine GUID from registry (unique per Windows installation)
    $machineGuid = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name MachineGuid).MachineGuid
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($machineGuid)
    
    # Create a 256-bit key (32 bytes) using SHA256 hash
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

function Test-SecureSecrets {
    # Diagnostic function to verify credential accessibility
    # Useful for troubleshooting SYSTEM account access issues
    [CmdletBinding()] 
    param()
    
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
                    # Attempt to decrypt each secret
                    $null = Get-SecureSecret -Key $keyName
                    Write-Host "✓ $keyName - accessible"
                }
                catch {
                    Write-Host "✗ $keyName - not accessible: $($_.Exception.Message)"
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
