@echo off
setlocal
echo ========================================================
echo          ApexOS Git Initialization & Push Helper
echo ========================================================

where git >nul 2>nul
if %errorlevel% neq 0 (
    echo [!] Git was not found in your PATH.
    echo [*] Installing Git using winget...
    winget install --id Git.Git -e --source winget
    echo [*] Please restart your terminal after installation to use git.
    pause
    exit /b 1
)

cd /d "d:\SatasOS"

if not exist ".git" (
    echo [*] Initializing new Git repository...
    git init
    git branch -M main
)

echo [*] Staging all ApexOS files...
git add .

echo [*] Creating commit...
git commit -m "feat: initial commit for ApexOS (Windows + Ubuntu + Android fusion)"

echo.
echo ========================================================
echo Now link this to your GitHub repository!
echo.
echo If you have not created a repository on GitHub yet:
echo 1. Go to https://github.com/new
echo 2. Name your repository (e.g., ApexOS) and click 'Create repository'
echo 3. Run the following two commands:
echo.
echo    git remote add origin https://github.com/YOUR_USERNAME/ApexOS.git
echo    git push -u origin main
echo ========================================================
echo.
pause
