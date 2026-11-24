<#
 One-time step: saves the Bootstrap Icons font files into the project so icons work OFFLINE.
 (The CSS file is already in wwwroot/css; only the two font files were missing.)

 Run from the Tools folder:   .\Download-IconFonts.ps1
 Manual alternative: download these two files and put them in  wwwroot\css\fonts\
   https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/fonts/bootstrap-icons.woff2
   https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/fonts/bootstrap-icons.woff
#>
param([string]$OutDir = (Join-Path $PSScriptRoot "..\RestaurantManagement\wwwroot\css\fonts"))
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$base = "https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/fonts/"
foreach ($f in "bootstrap-icons.woff2", "bootstrap-icons.woff") {
    Invoke-WebRequest -Uri ($base + $f) -OutFile (Join-Path $OutDir $f)
    Write-Host "Saved $f"
}
Write-Host "Done. Icons now load from /css/fonts/ with no internet needed."
