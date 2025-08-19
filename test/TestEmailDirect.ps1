# Direct test of Send-SecureMail with image embedding
param(
    [string]$RecipientEmail = "test@example.com"
)

# Import necessary modules
$ErrorActionPreference = 'Stop'

# Add module paths
$modulePath = (Resolve-Path "$PSScriptRoot\..\src\MailerCore.psm1").Path
Import-Module $modulePath -Force
Import-Module "$PSScriptRoot\..\config\SecureConfig.psm1" -Force -ErrorAction SilentlyContinue

# Load config
$configPath = "$PSScriptRoot\..\config\config.json"
$config = Get-Content -Raw -Path $configPath | ConvertFrom-Json

# Create a simple test HTML with logo placeholders
$testHtml = @"
<!DOCTYPE html>
<html>
<head><title>Test Email</title></head>
<body>
    <h1>Image Embedding Test</h1>
    <p>Logo 1 (AD-Ports): <img src="cid:logo1" alt="AD-Ports Logo" width="140" height="40"></p>
    <p>Logo 2 (Checkmarx): <img src="cid:logo2" alt="Checkmarx Logo" width="120" height="36"></p>
    <p>Test completed at: $(Get-Date)</p>
</body>
</html>
"@

Write-Host "Original HTML has cid references:" -ForegroundColor Yellow
Write-Host ($testHtml | Select-String 'src="cid:' -AllMatches).Matches.Value

# Save original HTML
$testHtml | Out-File "$PSScriptRoot\test_email_before.html" -Force

# Now let's manually run the image embedding logic
Write-Host "`nTesting image embedding logic..." -ForegroundColor Cyan

$scriptRoot = Split-Path -Parent $modulePath
$adPortsImagePath = "$scriptRoot\..\templates\static_assets\AD-Ports-Group.png"
$checkmarxImagePath = "$scriptRoot\..\templates\static_assets\Checkmarx_Logov1.jpg"

Write-Host "AD-Ports image path: $adPortsImagePath"
Write-Host "Checkmarx image path: $checkmarxImagePath"

$processedHtml = $testHtml

# Process AD-Ports logo
if (Test-Path $adPortsImagePath) {
    Write-Host "Processing AD-Ports logo..." -ForegroundColor Green
    $adPortsBytes = [System.IO.File]::ReadAllBytes($adPortsImagePath)
    $adPortsBase64 = [Convert]::ToBase64String($adPortsBytes)
    $adPortsDataUri = "data:image/png;base64,$adPortsBase64"
    $processedHtml = $processedHtml -replace 'src="cid:logo1"', "src=`"$adPortsDataUri`""
    Write-Host "Embedded AD-Ports logo (base64 length: $($adPortsBase64.Length))"
} else {
    Write-Host "AD-Ports logo not found!" -ForegroundColor Red
}

# Process Checkmarx logo
if (Test-Path $checkmarxImagePath) {
    Write-Host "Processing Checkmarx logo..." -ForegroundColor Green
    $checkmarxBytes = [System.IO.File]::ReadAllBytes($checkmarxImagePath)
    $checkmarxBase64 = [Convert]::ToBase64String($checkmarxBytes)
    $checkmarxDataUri = "data:image/jpeg;base64,$checkmarxBase64"
    $processedHtml = $processedHtml -replace 'src="cid:logo2"', "src=`"$checkmarxDataUri`""
    Write-Host "Embedded Checkmarx logo (base64 length: $($checkmarxBase64.Length))"
} else {
    Write-Host "Checkmarx logo not found!" -ForegroundColor Red
}

# Save processed HTML
$processedHtml | Out-File "$PSScriptRoot\test_email_after.html" -Force

Write-Host "`nProcessed HTML has data URIs:" -ForegroundColor Yellow
$matches = ($processedHtml | Select-String 'src="data:image' -AllMatches).Matches
Write-Host "Found $($matches.Count) embedded images"

Write-Host "`nHTML files saved:" -ForegroundColor Cyan
Write-Host "Before: test\test_email_before.html"
Write-Host "After: test\test_email_after.html"
Write-Host "`nOpen test_email_after.html in a browser to see if images display correctly." -ForegroundColor Green
