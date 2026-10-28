# ApexOS Git Push Automation Script for PowerShell

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "       ApexOS Git Repository Setup & Push Helper        " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# Check if git is available
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    Write-Host "[!] Git is not currently detected in your environment." -ForegroundColor Yellow
    Write-Host "[*] You can install it quickly with: winget install --id Git.Git -e --source winget" -ForegroundColor Green
    Write-Host "[*] Or download from: https://git-scm.com/download/win" -ForegroundColor Green
    exit 1
}

Set-Location "d:\SatasOS"

if (-not (Test-Path ".git")) {
    Write-Host "[*] Initializing local git repository..." -ForegroundColor Cyan
    git init
    git branch -M main
}

Write-Host "[*] Adding ApexOS project files..." -ForegroundColor Cyan
git add .

Write-Host "[*] Committing files..." -ForegroundColor Cyan
git commit -m "feat: complete ApexOS multi-platform distro source and cloud ISO builder"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "Ready to push to GitHub!" -ForegroundColor Green
Write-Host "Run these two commands with your GitHub repo URL:" -ForegroundColor White
Write-Host ""
Write-Host "  git remote add origin https://github.com/YOUR_USERNAME/ApexOS.git" -ForegroundColor Yellow
Write-Host "  git push -u origin main" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Green
