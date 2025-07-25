function Set-SecureSecret {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Secret
    )
    $cred = New-Object PSCredential($Key,(ConvertTo-SecureString $Secret -AsPlainText -Force))
    $null = cmd /c "cmdkey /generic:$Key /user:$Key /pass:$Secret"
}

function Get-SecureSecret {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$Key
    )
    $output = cmd /c "cmdkey /list:$Key" 2>$null
    if ($LASTEXITCODE) { throw "Secret $Key not found" }
    ($output -split ' ')[-1]
}
Export-ModuleMember -Function *-SecureSecret
