# LinqPadCompiler Uninstallation Script for Windows
# Usage: .\uninstall.ps1 [-System]
# 
# Examples:
#   User uninstallation (default):
#     .\uninstall.ps1
#   
#   System-wide uninstallation (requires admin):
#     .\uninstall.ps1 -System

param(
    [switch]$System
)

$ErrorActionPreference = 'Stop'

# Colors for output (fallback to no color if not supported)
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-Host "LinqPadCompiler Uninstallation Script" -ForegroundColor Green

# Determine uninstallation directory based on -System flag
if ($System) {
    # Check for admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Host "Error: System-wide uninstallation requires Administrator privileges" -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator and try again:" -ForegroundColor Yellow
        Write-Host "  .\uninstall.ps1 -System" -ForegroundColor Blue
        exit 1
    }
    $installDir = "$env:ProgramFiles\LinqPadCompiler"
    $pathScope = "Machine"
    Write-Host "Uninstalling system-wide installation..." -ForegroundColor Yellow
} else {
    $installDir = "$env:LOCALAPPDATA\LinqPadCompiler"
    $pathScope = "User"
    Write-Host "Uninstalling user installation..." -ForegroundColor Yellow
}

$binDir = "$installDir\bin"
Write-Host ""

# Check if LinqPadCompiler exists
$exePath = "$binDir\linqpadcompiler.exe"
$batPath = "$binDir\linqpadcompiler.bat"
$installExists = (Test-Path $exePath) -or (Test-Path $batPath) -or (Test-Path $binDir)

if (-not $installExists) {
    Write-Host "Warning: LinqPadCompiler not found in $installDir" -ForegroundColor Yellow
    Write-Host "Nothing to uninstall." -ForegroundColor Yellow
    
    # Check if it exists in the other location
    if ($System) {
        $altPath = "$env:LOCALAPPDATA\LinqPadCompiler\bin"
        if (Test-Path $altPath) {
            Write-Host ""
            Write-Host "Note: User installation found at $altPath" -ForegroundColor Blue
            Write-Host "To uninstall that, run: .\uninstall.ps1" -ForegroundColor Blue
        }
    } else {
        $altPath = "$env:ProgramFiles\LinqPadCompiler\bin"
        if (Test-Path $altPath) {
            Write-Host ""
            Write-Host "Note: System-wide installation found at $altPath" -ForegroundColor Blue
            Write-Host "To uninstall that, run as Administrator: .\uninstall.ps1 -System" -ForegroundColor Blue
        }
    }
    exit 0
}

try {
    # Remove from PATH
    Write-Host "Removing from PATH ($pathScope scope)..." -ForegroundColor Yellow
    $currentPath = [Environment]::GetEnvironmentVariable("Path", $pathScope)
    if ($currentPath -like "*$binDir*") {
        # Remove the binDir from PATH
        $newPath = ($currentPath.Split(';') | Where-Object { $_ -ne $binDir }) -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newPath, $pathScope)
        Write-Host "✓ Removed from PATH" -ForegroundColor Green
    } else {
        Write-Host "✓ Not found in PATH (already removed)" -ForegroundColor Green
    }
    
    # Remove installation directory
    if (Test-Path $installDir) {
        Write-Host "Removing installation directory..." -ForegroundColor Yellow
        Remove-Item -Path $installDir -Recurse -Force
        Write-Host "✓ Removed $installDir" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "✓ LinqPadCompiler has been uninstalled successfully!" -ForegroundColor Green
    
    # Final confirmation
    Write-Host ""
    if ($System) {
        Write-Host "System-wide uninstallation complete." -ForegroundColor Blue
    } else {
        Write-Host "User uninstallation complete." -ForegroundColor Blue
    }
    
    Write-Host ""
    Write-Host "Note: You may need to restart your terminal for PATH changes to take effect." -ForegroundColor Yellow
    
} catch {
    Write-Host "Uninstallation failed: $_" -ForegroundColor Red
    exit 1
}