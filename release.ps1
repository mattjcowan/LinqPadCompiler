# LinqPadCompiler Release Script for Windows
# Usage: .\release.ps1 [patch|minor|major] [message]
# Examples:
#   .\release.ps1              # Auto-detect version bump from commits
#   .\release.ps1 patch        # Bump patch version
#   .\release.ps1 minor        # Bump minor version  
#   .\release.ps1 major        # Bump major version
#   .\release.ps1 patch "Fixed critical bug"  # With custom message

param(
    [ValidateSet('patch', 'minor', 'major', '')]
    [string]$BumpType = '',
    [string]$Message = ''
)

$ErrorActionPreference = 'Stop'

# Function to read current version from version.json
function Get-CurrentVersion {
    if (-not (Test-Path "version.json")) {
        Write-Host "Error: version.json not found" -ForegroundColor Red
        exit 1
    }
    
    $json = Get-Content "version.json" | ConvertFrom-Json
    return $json.version
}

# Function to bump version
function Bump-Version {
    param(
        [string]$CurrentVersion,
        [string]$BumpType
    )
    
    # Remove 'v' prefix if present
    $CurrentVersion = $CurrentVersion.TrimStart('v')
    
    # Split version into components
    $parts = $CurrentVersion.Split('.')
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]
    
    switch ($BumpType) {
        'major' {
            $major++
            $minor = 0
            $patch = 0
        }
        'minor' {
            $minor++
            $patch = 0
        }
        'patch' {
            $patch++
        }
        default {
            Write-Host "Invalid bump type: $BumpType" -ForegroundColor Red
            exit 1
        }
    }
    
    return "$major.$minor.$patch"
}

# Function to detect version bump from commits
function Detect-VersionBump {
    try {
        $lastTag = git describe --tags --abbrev=0 2>$null
    } catch {
        Write-Host "No previous tags found. Using patch bump." -ForegroundColor Yellow
        return 'patch'
    }
    
    if (-not $lastTag) {
        return 'patch'
    }
    
    # Check commit messages since last tag
    $commits = git log "$lastTag..HEAD" --pretty=format:"%s"
    
    $bump = 'patch'  # Default
    
    if ($commits -match 'BREAKING CHANGE:|feat!:|fix!:') {
        $bump = 'major'
    } elseif ($commits -match '^feat:') {
        $bump = 'minor'
    }
    
    return $bump
}

# Function to generate changelog entry
function Generate-ChangelogEntry {
    param(
        [string]$Version
    )
    
    $date = Get-Date -Format "yyyy-MM-dd"
    $output = "## [$Version] - $date`n`n"
    
    try {
        $lastTag = git describe --tags --abbrev=0 2>$null
    } catch {
        $lastTag = $null
    }
    
    if ($lastTag) {
        # Get commits since last tag
        $commits = git log "$lastTag..HEAD" --pretty=format:"%s|%h"
        
        $features = @()
        $fixes = @()
        $breaking = @()
        $other = @()
        
        foreach ($commit in $commits) {
            $parts = $commit.Split('|')
            if ($parts.Length -ge 2) {
                $msg = $parts[0]
                $hash = $parts[1]
                
                if ($msg -match '^BREAKING CHANGE:|^[a-z]+!:') {
                    $breaking += "- $msg ($hash)"
                } elseif ($msg -match '^feat(\(.*\))?:\s*(.*)') {
                    $features += "- $($matches[2]) ($hash)"
                } elseif ($msg -match '^fix(\(.*\))?:\s*(.*)') {
                    $fixes += "- $($matches[2]) ($hash)"
                } else {
                    $other += "- $msg ($hash)"
                }
            }
        }
        
        # Output grouped changes
        if ($breaking.Count -gt 0) {
            $output += "### Breaking Changes`n"
            $output += ($breaking -join "`n") + "`n`n"
        }
        
        if ($features.Count -gt 0) {
            $output += "### Added`n"
            $output += ($features -join "`n") + "`n`n"
        }
        
        if ($fixes.Count -gt 0) {
            $output += "### Fixed`n"
            $output += ($fixes -join "`n") + "`n`n"
        }
        
        if ($other.Count -gt 0) {
            $output += "### Changed`n"
            $output += ($other -join "`n") + "`n`n"
        }
    } else {
        $output += "### Added`n- Initial release`n`n"
    }
    
    return $output
}

# Function to update version in file
function Update-VersionInFile {
    param(
        [string]$FilePath,
        [string]$OldVersion,
        [string]$NewVersion
    )
    
    if (Test-Path $FilePath) {
        $content = Get-Content $FilePath -Raw
        $content = $content -replace [regex]::Escape($OldVersion), $NewVersion
        Set-Content -Path $FilePath -Value $content -NoNewline
        Write-Host "✓ Updated version in $FilePath" -ForegroundColor Green
    }
}

# Main script
Write-Host "LinqPadCompiler Release Script" -ForegroundColor Green
Write-Host ""

# Check if we're in a git repository
try {
    git rev-parse --git-dir 2>&1 | Out-Null
} catch {
    Write-Host "Error: Not in a git repository" -ForegroundColor Red
    exit 1
}

# Check for uncommitted changes
$status = git status --porcelain
if ($status) {
    Write-Host "Error: You have uncommitted changes. Please commit or stash them first." -ForegroundColor Red
    exit 1
}

# Check we're on main/master branch
$currentBranch = git branch --show-current
if ($currentBranch -ne 'main' -and $currentBranch -ne 'master') {
    Write-Host "Warning: You're on branch '$currentBranch', not main/master." -ForegroundColor Yellow
    $response = Read-Host "Continue anyway? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        exit 1
    }
}

# Get current version
$currentVersion = Get-CurrentVersion
Write-Host "Current version: $currentVersion" -ForegroundColor Blue

# Determine version bump type
if (-not $BumpType) {
    $BumpType = Detect-VersionBump
}

if ($BumpType -notin @('patch', 'minor', 'major')) {
    Write-Host "Invalid argument. Use: patch, minor, or major" -ForegroundColor Red
    exit 1
}

Write-Host "Bump type: $BumpType" -ForegroundColor Blue

# Calculate new version
$newVersion = Bump-Version -CurrentVersion $currentVersion -BumpType $BumpType
Write-Host "New version: $newVersion" -ForegroundColor Blue

# Confirm with user
Write-Host ""
$response = Read-Host "Proceed with release v$newVersion? (y/N)"
if ($response -ne 'y' -and $response -ne 'Y') {
    Write-Host "Release cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Updating version files..." -ForegroundColor Yellow

# Update version.json
$versionJson = Get-Content "version.json" | ConvertFrom-Json
$versionJson.version = $newVersion
$versionJson | ConvertTo-Json | Set-Content "version.json"
Write-Host "✓ Updated version.json" -ForegroundColor Green

# Update Directory.Build.props
Update-VersionInFile -FilePath "Directory.Build.props" -OldVersion $currentVersion -NewVersion $newVersion
# Also update assembly versions (with .0 suffix)
$content = Get-Content "Directory.Build.props" -Raw
$content = $content -replace "$($currentVersion).0", "$($newVersion).0"
Set-Content -Path "Directory.Build.props" -Value $content -NoNewline

# Generate changelog entry
Write-Host "Generating changelog..." -ForegroundColor Yellow
$changelogEntry = Generate-ChangelogEntry -Version "v$newVersion"

# Update or create CHANGELOG.md
if (Test-Path "CHANGELOG.md") {
    # Get existing content (skip first 2 lines)
    $existingContent = Get-Content "CHANGELOG.md" -Raw
    $lines = $existingContent -split "`n"
    if ($lines.Count -gt 2) {
        $existingBody = ($lines[2..($lines.Count-1)] -join "`n")
    } else {
        $existingBody = ""
    }
    
    $newChangelog = "# Changelog`n`n$changelogEntry`n$existingBody"
} else {
    $newChangelog = "# Changelog`n`n$changelogEntry"
}

Set-Content -Path "CHANGELOG.md" -Value $newChangelog -NoNewline
Write-Host "✓ Updated CHANGELOG.md" -ForegroundColor Green

# Stage all changes
Write-Host "Staging changes..." -ForegroundColor Yellow
git add version.json Directory.Build.props CHANGELOG.md

# Commit changes
$commitMessage = "chore: release v$newVersion"
if ($Message) {
    $commitMessage = "$commitMessage - $Message"
}

Write-Host "Committing changes..." -ForegroundColor Yellow
git commit -m $commitMessage
Write-Host "✓ Created commit" -ForegroundColor Green

# Create tag
Write-Host "Creating tag v$newVersion..." -ForegroundColor Yellow
git tag -a "v$newVersion" -m "Release v$newVersion"
Write-Host "✓ Created tag v$newVersion" -ForegroundColor Green

# Push changes
Write-Host ""
Write-Host "Ready to push changes and tag to remote." -ForegroundColor Yellow
$response = Read-Host "Push to remote? (y/N)"
if ($response -eq 'y' -or $response -eq 'Y') {
    Write-Host "Pushing to remote..." -ForegroundColor Yellow
    git push origin $currentBranch
    git push origin "v$newVersion"
    Write-Host "✓ Pushed changes and tag to remote" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎉 Release v$newVersion complete!" -ForegroundColor Green
    Write-Host "GitHub Actions will now build and create the release." -ForegroundColor Blue
    Write-Host "Check: https://github.com/mattjcowan/LinqPadCompiler/actions" -ForegroundColor Blue
} else {
    Write-Host "Changes committed and tagged locally." -ForegroundColor Yellow
    Write-Host "To push later, run:" -ForegroundColor Yellow
    Write-Host "  git push origin $currentBranch" -ForegroundColor Blue
    Write-Host "  git push origin v$newVersion" -ForegroundColor Blue
}