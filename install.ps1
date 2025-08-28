# LinqPadCompiler Installation Script for Windows
# Usage: irm https://raw.githubusercontent.com/mattjcowan/LinqPadCompiler/main/install.ps1 | iex
# Or download and run: .\install.ps1 [-Variant lite|full] [-System]
# 
# Examples:
#   User installation (default):
#     irm .../install.ps1 | iex
#   
#   System-wide installation (requires admin):
#     irm .../install.ps1 | iex -System
#   
#   System-wide with full variant:
#     .\install.ps1 -Variant full -System

param(
    [ValidateSet('lite', 'full', '')]
    [string]$Variant = '',
    [switch]$System
)

$ErrorActionPreference = 'Stop'

# Configuration
$repo = "mattjcowan/LinqPadCompiler"

# Determine installation directory based on -System flag
if ($System) {
    # Check for admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Host "Error: System-wide installation requires Administrator privileges" -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator and try again:" -ForegroundColor Yellow
        Write-Host "  irm https://raw.githubusercontent.com/mattjcowan/LinqPadCompiler/main/install.ps1 | iex -System" -ForegroundColor Blue
        exit 1
    }
    $installDir = "$env:ProgramFiles\LinqPadCompiler"
    $pathScope = "Machine"
} else {
    $installDir = "$env:LOCALAPPDATA\LinqPadCompiler"
    $pathScope = "User"
}
$binDir = "$installDir\bin"

# Colors for output
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-Host "LinqPadCompiler Installation Script" -ForegroundColor Green
Write-Host "Repository: https://github.com/$repo" -ForegroundColor Blue
if ($System) {
    Write-Host "Installing system-wide for all users..." -ForegroundColor Yellow
} else {
    Write-Host "Installing for current user only..." -ForegroundColor Yellow
}
Write-Host ""

# Detect platform
$platform = "win-x64"
Write-Host "Platform: $platform" -ForegroundColor Blue

# Check if .NET SDK is available
function Test-DotNetSDK {
    try {
        $dotnetVersion = & dotnet --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $dotnetVersion) {
            return "found:$dotnetVersion"
        }
    } catch {
        # Ignore error
    }
    return "not-found"
}

# Determine appropriate variant
function Get-InstallVariant {
    if ($Variant) {
        return $Variant
    }
    
    Write-Host "Checking .NET SDK availability..." -ForegroundColor Yellow
    $sdkStatus = Test-DotNetSDK
    
    if ($sdkStatus -like "found:*") {
        $version = $sdkStatus.Substring(6)
        Write-Host "✓ .NET SDK found: $version" -ForegroundColor Green
        Write-Host "Recommendation: Using 'lite' variant (~10MB)" -ForegroundColor Blue
        return "lite"
    } else {
        Write-Host "⚠ .NET SDK not found" -ForegroundColor Yellow
        Write-Host "Recommendation: Use 'full' variant (~200MB) for complete self-contained installation" -ForegroundColor Blue
        Write-Host "Installing 'lite' variant by default. You can install the 'full' variant with:" -ForegroundColor Yellow
        Write-Host ".\install.ps1 -Variant full" -ForegroundColor Blue
        Write-Host ""
        return "lite"
    }
}

# Get latest release version
function Get-LatestRelease {
    try {
        $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest"
        return $releases.tag_name
    } catch {
        Write-Host "Failed to get latest release information" -ForegroundColor Red
        throw
    }
}

# Main installation
try {
    # Determine variant
    $installVariant = Get-InstallVariant
    Write-Host "Installing variant: $installVariant" -ForegroundColor Green
    Write-Host ""
    
    # Get latest version
    Write-Host "Getting latest release information..." -ForegroundColor Yellow
    $version = Get-LatestRelease
    Write-Host "Latest version: $version" -ForegroundColor Blue
    
    # Construct download URL
    $archiveName = "linqpadcompiler-$installVariant-$platform.zip"
    $downloadUrl = "https://github.com/$repo/releases/download/$version/$archiveName"
    
    Write-Host "Downloading $archiveName..." -ForegroundColor Yellow
    
    # Create temp directory
    $tempDir = Join-Path $env:TEMP "linqpadcompiler-install-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    
    try {
        # Download archive
        $archivePath = Join-Path $tempDir $archiveName
        Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath
        
        # Extract archive
        Write-Host "Extracting archive..." -ForegroundColor Yellow
        Expand-Archive -Path $archivePath -DestinationPath $tempDir -Force
        
        # Create installation directory
        if (Test-Path $binDir) {
            Remove-Item -Path $binDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
        
        # Copy files
        $sourceDir = Join-Path $tempDir "$installVariant-$platform"
        Copy-Item -Path "$sourceDir\*" -Destination $binDir -Recurse
        
        # Add to PATH if not already there
        $currentPath = [Environment]::GetEnvironmentVariable("Path", $pathScope)
        if ($currentPath -notlike "*$binDir*") {
            Write-Host "Adding to PATH ($pathScope scope)..." -ForegroundColor Yellow
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$binDir", $pathScope)
            $env:Path = "$env:Path;$binDir"
            if ($System) {
                Write-Host "✓ Added to system PATH (restart terminal to use globally)" -ForegroundColor Green
            } else {
                Write-Host "✓ Added to user PATH (restart terminal to use globally)" -ForegroundColor Green
            }
        } else {
            Write-Host "✓ Already in PATH" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "✓ LinqPadCompiler ($installVariant variant) installed successfully!" -ForegroundColor Green
        if ($System) {
            Write-Host "System-wide installation location: $binDir" -ForegroundColor Blue
            Write-Host "✓ Available to all users including SYSTEM account and scheduled tasks" -ForegroundColor Green
        } else {
            Write-Host "User installation location: $binDir" -ForegroundColor Blue
        }
        
        # Show variant-specific information
        if ($installVariant -eq "full") {
            Write-Host "✓ Bundled .NET SDK included - no additional dependencies required" -ForegroundColor Green
        } else {
            $sdkStatus = Test-DotNetSDK
            if ($sdkStatus -eq "not-found") {
                Write-Host "⚠ Warning: .NET SDK is required to compile LINQPad scripts" -ForegroundColor Yellow
                Write-Host "  Install .NET SDK from: https://dotnet.microsoft.com/download" -ForegroundColor Yellow
                Write-Host "  Or use the full variant: .\install.ps1 -Variant full" -ForegroundColor Yellow
            }
        }
        
        # Test installation
        Write-Host ""
        Write-Host "Testing installation..." -ForegroundColor Yellow
        
        # Try to run help command
        try {
            & "$binDir\linqpadcompiler.exe" --help | Out-Null
            Write-Host "✓ Installation test passed!" -ForegroundColor Green
        } catch {
            & "$binDir\linqpadcompiler.bat" --help | Out-Null
            Write-Host "✓ Installation test passed!" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "Usage examples:" -ForegroundColor Green
        Write-Host "  linqpadcompiler --linq-file script.linq --output-dir .\output --create" -ForegroundColor Blue
        Write-Host "  linqpadcompiler --linq-file script.linq --output-dir .\output --output-type SingleFileDll" -ForegroundColor Blue
        
    } finally {
        # Clean up temp directory
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
} catch {
    Write-Host "Installation failed: $_" -ForegroundColor Red
    exit 1
}