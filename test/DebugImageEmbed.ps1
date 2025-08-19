# Debug script to trace image embedding issue

$modulePath = (Resolve-Path "$PSScriptRoot\..\src\MailerCore.psm1").Path
$scriptRoot = Split-Path -Parent $modulePath

# Test paths
$adPortsImagePath = "$scriptRoot\..\templates\static_assets\AD-Ports-Group.png"
$checkmarxImagePath = "$scriptRoot\..\templates\static_assets\Checkmarx_Logov1.jpg"

Write-Host "=== PATH DEBUGGING ===" -ForegroundColor Cyan
Write-Host "Module path: $modulePath"
Write-Host "Script root: $scriptRoot"
Write-Host "AD-Ports path: $adPortsImagePath"
Write-Host "Checkmarx path: $checkmarxImagePath"
Write-Host ""

# Check if paths exist
Write-Host "=== FILE EXISTENCE ===" -ForegroundColor Cyan
Write-Host "AD-Ports exists: $(Test-Path $adPortsImagePath)"
Write-Host "Checkmarx exists: $(Test-Path $checkmarxImagePath)"
Write-Host ""

# Test HTML with CID references
$testHtml = @'
<html>
<body>
<p>Test 1: <img src="cid:logo1" alt="logo1"></p>
<p>Test 2: <img src="cid:logo2" alt="logo2"></p>
</body>
</html>
'@

Write-Host "=== ORIGINAL HTML ===" -ForegroundColor Cyan
Write-Host $testHtml
Write-Host ""

# Simulate the replacement logic from Send-SecureMail
$processedHtml = $testHtml

if (Test-Path $adPortsImagePath) {
    Write-Host "=== PROCESSING AD-PORTS LOGO ===" -ForegroundColor Green
    $adPortsBytes = [System.IO.File]::ReadAllBytes($adPortsImagePath)
    Write-Host "Image size: $($adPortsBytes.Length) bytes"
    
    $adPortsBase64 = [Convert]::ToBase64String($adPortsBytes)
    Write-Host "Base64 length: $($adPortsBase64.Length) chars"
    Write-Host "Base64 preview: $($adPortsBase64.Substring(0, 50))..."
    
    $adPortsDataUri = "data:image/png;base64,$adPortsBase64"
    Write-Host "Data URI length: $($adPortsDataUri.Length) chars"
    
    # Test replacement
    $beforeReplace = $processedHtml
    $processedHtml = $processedHtml -replace 'src="cid:logo1"', "src=`"$adPortsDataUri`""
    
    if ($beforeReplace -eq $processedHtml) {
        Write-Host "WARNING: No replacement occurred for logo1!" -ForegroundColor Red
    } else {
        Write-Host "SUCCESS: Replacement occurred for logo1" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== CHECKING REPLACEMENT ===" -ForegroundColor Cyan
$matches = [regex]::Matches($processedHtml, 'src="([^"]+)"')
foreach ($match in $matches) {
    $src = $match.Groups[1].Value
    if ($src.StartsWith("data:")) {
        Write-Host "Found data URI: $(if($src.Length -gt 100) { $src.Substring(0, 100) + '...' } else { $src })" -ForegroundColor Green
    } else {
        Write-Host "Found non-data URI: $src" -ForegroundColor Yellow
    }
}

# Save debug output
$processedHtml | Out-File "$PSScriptRoot\debug_processed.html" -Force
Write-Host ""
Write-Host "Debug HTML saved to: test\debug_processed.html" -ForegroundColor Cyan

# Let's also check what's in the actual MailerCore module
Write-Host ""
Write-Host "=== CHECKING MAILERCORE MODULE ===" -ForegroundColor Cyan
$moduleContent = Get-Content $modulePath -Raw
$sendSecureMailStart = $moduleContent.IndexOf("function Send-SecureMail")
if ($sendSecureMailStart -ge 0) {
    $functionContent = $moduleContent.Substring($sendSecureMailStart, 2000)
    if ($functionContent -match "data:image") {
        Write-Host "Found 'data:image' in Send-SecureMail function" -ForegroundColor Green
    } else {
        Write-Host "WARNING: 'data:image' not found in Send-SecureMail function!" -ForegroundColor Red
    }
    
    if ($functionContent -match "Test-Path.*static_assets") {
        Write-Host "Found image path checking in Send-SecureMail" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Image path checking not found!" -ForegroundColor Red
    }
}
