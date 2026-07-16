# Build and deploy to GitHub Pages
# Usage: run in PowerShell outside sandbox
# .\build-and-deploy.ps1

$ErrorActionPreference = "Stop"

$env:JAVA_HOME = "D:\_Dev\_Compiler\corretto-17.0.12"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

Write-Host "=== Build miuix (production wasmJs) ===" -ForegroundColor Cyan
Set-Location "$repoRoot\miuix-main"
.\gradlew.bat :example:web:wasmJsBrowserProductionWebpack --no-daemon --console=plain
if ($LASTEXITCODE -ne 0) { Write-Host "miuix build failed" -ForegroundColor Red; exit 1 }

Write-Host "=== Build kyant (production wasmJs) ===" -ForegroundColor Cyan
Set-Location "$repoRoot\AndroidLiquidGlass-kmp"
.\gradlew.bat :app:wasmJsBrowserProductionWebpack --no-daemon --console=plain
if ($LASTEXITCODE -ne 0) { Write-Host "kyant build failed" -ForegroundColor Red; exit 1 }

Write-Host "=== Copy artifacts to docs/ ===" -ForegroundColor Cyan
$docsDir = "$repoRoot\docs"

$miuixWebpack = "$repoRoot\miuix-main\example\web\build\kotlin-webpack\wasmJs\productionExecutable"
$kyantWebpack = "$repoRoot\AndroidLiquidGlass-kmp\app\build\kotlin-webpack\wasmJs\productionExecutable"
$miuixRes = "$repoRoot\miuix-main\example\web\build\processedResources\wasmJs\main"
$kyantRes = "$repoRoot\AndroidLiquidGlass-kmp\app\build\processedResources\wasmJs\main"

foreach ($p in @($miuixWebpack, $kyantWebpack, $miuixRes, $kyantRes)) {
    if (-not (Test-Path $p)) {
        Write-Host "Path not found: $p" -ForegroundColor Red
        exit 1
    }
}

if (Test-Path "$docsDir\miuix") { Remove-Item "$docsDir\miuix" -Recurse -Force }
if (Test-Path "$docsDir\kyant") { Remove-Item "$docsDir\kyant" -Recurse -Force }

New-Item -ItemType Directory -Force -Path "$docsDir\miuix" | Out-Null
New-Item -ItemType Directory -Force -Path "$docsDir\kyant" | Out-Null

# Copy webpack output (js + wasm)
Copy-Item "$miuixWebpack\*" "$docsDir\miuix\" -Recurse -Force
Copy-Item "$kyantWebpack\*" "$docsDir\kyant\" -Recurse -Force

# Copy processedResources (index.html, css, images, fonts, composeResources)
Copy-Item "$miuixRes\*" "$docsDir\miuix\" -Recurse -Force
Copy-Item "$kyantRes\*" "$docsDir\kyant\" -Recurse -Force

Write-Host ""
Write-Host "=== Artifacts ===" -ForegroundColor Green
Write-Host "miuix:" -ForegroundColor Cyan
Get-ChildItem "$docsDir\miuix" -File | ForEach-Object {
    Write-Host ("  {0,-35} {1:N2} MB" -f $_.Name, ($_.Length / 1MB))
}
Write-Host "kyant:" -ForegroundColor Cyan
Get-ChildItem "$docsDir\kyant" -File | ForEach-Object {
    Write-Host ("  {0,-35} {1:N2} MB" -f $_.Name, ($_.Length / 1MB))
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "Artifacts copied to docs/"
Write-Host "Push to GitHub, then enable Pages: Settings -> Pages -> main / docs"
Write-Host "URL: https://<username>.github.io/<repo>/"