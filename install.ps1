# LinqPadCompiler Installation Script for Windows
# Usage: irm https://raw.githubusercontent.com/mattjcowan/LinqPadCompiler/main/install.ps1 | iex
# Or download and run: .\install.ps1 [-Variant lite|full]

param(
    [ValidateSet('lite', 'full', '')]
    [string]$Variant = ''
)

$ErrorActionPreference = 'Stop'

# Configuration
$repo = "mattjcowan/LinqPadCompiler"
$installDir = "$env:LOCALAPPDATA\LinqPadCompiler"
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
        Write-Host "irm https://raw.githubusercontent.com/mattjcowan/LinqPadCompiler/main/install.ps1 | iex -Variant full" -ForegroundColor Blue
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
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$binDir*") {
            Write-Host "Adding to PATH..." -ForegroundColor Yellow
            [Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
            $env:Path = "$env:Path;$binDir"
            Write-Host "✓ Added to PATH (restart terminal to use globally)" -ForegroundColor Green
        } else {
            Write-Host "✓ Already in PATH" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "✓ LinqPadCompiler ($installVariant variant) installed successfully!" -ForegroundColor Green
        Write-Host "Installation location: $binDir" -ForegroundColor Blue
        
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