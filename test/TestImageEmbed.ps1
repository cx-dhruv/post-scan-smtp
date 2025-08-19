# Direct test of image embedding logic

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$adPortsImagePath = "$scriptDir\..\templates\static_assets\AD-Ports-Group.png"
$checkmarxImagePath = "$scriptDir\..\templates\static_assets\Checkmarx_Logov1.jpg"

Write-Host "Testing image paths:"
Write-Host "AD-Ports path: $adPortsImagePath"
Write-Host "Checkmarx path: $checkmarxImagePath"
Write-Host ""

Write-Host "Checking if files exist:"
Write-Host "AD-Ports exists: $(Test-Path $adPortsImagePath)"
Write-Host "Checkmarx exists: $(Test-Path $checkmarxImagePath)"
Write-Host ""

# Test base64 encoding
if (Test-Path $adPortsImagePath) {
    $adPortsBytes = [System.IO.File]::ReadAllBytes($adPortsImagePath)
    $adPortsBase64 = [Convert]::ToBase64String($adPortsBytes)
    Write-Host "AD-Ports image size: $($adPortsBytes.Length) bytes"
    Write-Host "AD-Ports base64 length: $($adPortsBase64.Length) chars"
    Write-Host "AD-Ports base64 preview: $($adPortsBase64.Substring(0, 50))..."
}

if (Test-Path $checkmarxImagePath) {
    $checkmarxBytes = [System.IO.File]::ReadAllBytes($checkmarxImagePath)
    $checkmarxBase64 = [Convert]::ToBase64String($checkmarxBytes)
    Write-Host "Checkmarx image size: $($checkmarxBytes.Length) bytes"
    Write-Host "Checkmarx base64 length: $($checkmarxBase64.Length) chars"
    Write-Host "Checkmarx base64 preview: $($checkmarxBase64.Substring(0, 50))..."
}

# Test HTML replacement
$testHtml = '<img src="cid:logo1" alt="test1"><img src="cid:logo2" alt="test2">'
Write-Host ""
Write-Host "Original HTML: $testHtml"

if (Test-Path $adPortsImagePath) {
    $adPortsDataUri = "data:image/png;base64,$adPortsBase64"
    $testHtml = $testHtml -replace 'src="cid:logo1"', "src=`"data:image/png;base64,TEST1`""
    Write-Host "After logo1 replace: $($testHtml.Substring(0, 100))..."
}

if (Test-Path $checkmarxImagePath) {
    $checkmarxDataUri = "data:image/jpeg;base64,$checkmarxBase64"
    $testHtml = $testHtml -replace 'src="cid:logo2"', "src=`"data:image/jpeg;base64,TEST2`""
    Write-Host "After logo2 replace: $($testHtml.Substring(0, 100))..."
}
