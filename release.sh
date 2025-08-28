#!/bin/bash

# LinqPadCompiler Release Script
# Usage: ./release.sh [patch|minor|major] [message]
# Examples:
#   ./release.sh              # Auto-detect version bump from commits
#   ./release.sh patch        # Bump patch version
#   ./release.sh minor        # Bump minor version  
#   ./release.sh major        # Bump major version
#   ./release.sh patch "Fixed critical bug"  # With custom message

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to read current version from version.json
get_current_version() {
    if [ ! -f "version.json" ]; then
        echo -e "${RED}Error: version.json not found${NC}"
        exit 1
    fi
    grep -o '"version": *"[^"]*"' version.json | sed 's/"version": *"\(.*\)"/\1/'
}

# Function to bump version
bump_version() {
    local current_version=$1
    local bump_type=$2
    
    # Remove 'v' prefix if present
    current_version=${current_version#v}
    
    # Split version into components
    IFS='.' read -r major minor patch <<< "$current_version"
    
    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo -e "${RED}Invalid bump type: $bump_type${NC}"
            exit 1
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# Function to detect version bump from commits
detect_version_bump() {
    local last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    local bump="patch"  # Default to patch
    
    if [ -z "$last_tag" ]; then
        echo -e "${YELLOW}No previous tags found. Using patch bump.${NC}"
        echo "patch"
        return
    fi
    
    # Check commit messages since last tag
    local commits=$(git log "$last_tag"..HEAD --pretty=format:"%s")
    
    if echo "$commits" | grep -q "BREAKING CHANGE:\|feat!:\|fix!:"; then
        bump="major"
    elif echo "$commits" | grep -q "^feat:"; then
        bump="minor"
    fi
    
    echo "$bump"
}

# Function to generate changelog entry
generate_changelog_entry() {
    local version=$1
    local last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    local date=$(date +%Y-%m-%d)
    
    echo "## [$version] - $date"
    echo ""
    
    if [ -n "$last_tag" ]; then
        # Get commits since last tag
        local commits=$(git log "$last_tag"..HEAD --pretty=format:"%s|%h")
        
        # Group commits by type
        local features=""
        local fixes=""
        local breaking=""
        local other=""
        
        while IFS='|' read -r message hash; do
            if [[ "$message" =~ ^BREAKING\ CHANGE:|^[a-z]+!: ]]; then
                breaking="${breaking}- ${message} (${hash})\n"
            elif [[ "$message" =~ ^feat(\(.*\))?:\ .* ]]; then
                features="${features}- ${message#*: } (${hash})\n"
            elif [[ "$message" =~ ^fix(\(.*\))?:\ .* ]]; then
                fixes="${fixes}- ${message#*: } (${hash})\n"
            else
                other="${other}- ${message} (${hash})\n"
            fi
        done <<< "$commits"
        
        # Output grouped changes
        if [ -n "$breaking" ]; then
            echo "### Breaking Changes"
            echo -e "$breaking"
        fi
        
        if [ -n "$features" ]; then
            echo "### Added"
            echo -e "$features"
        fi
        
        if [ -n "$fixes" ]; then
            echo "### Fixed"
            echo -e "$fixes"
        fi
        
        if [ -n "$other" ]; then
            echo "### Changed"
            echo -e "$other"
        fi
    else
        echo "### Added"
        echo "- Initial release"
        echo ""
    fi
}

# Function to update version in file
update_version_in_file() {
    local file=$1
    local old_version=$2
    local new_version=$3
    
    if [ -f "$file" ]; then
        # Use sed to replace version strings
        sed -i.bak "s/$old_version/$new_version/g" "$file"
        rm "$file.bak"
        echo -e "${GREEN}✓ Updated version in $file${NC}"
    fi
}

# Main script
main() {
    echo -e "${GREEN}LinqPadCompiler Release Script${NC}"
    echo ""
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}Error: Not in a git repository${NC}"
        exit 1
    fi
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        echo -e "${RED}Error: You have uncommitted changes. Please commit or stash them first.${NC}"
        exit 1
    fi
    
    # Check we're on main/master branch
    current_branch=$(git branch --show-current)
    if [[ "$current_branch" != "main" && "$current_branch" != "master" ]]; then
        echo -e "${YELLOW}Warning: You're on branch '$current_branch', not main/master.${NC}"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Get current version
    current_version=$(get_current_version)
    echo -e "${BLUE}Current version: $current_version${NC}"
    
    # Determine version bump type
    bump_type=${1:-$(detect_version_bump)}
    custom_message=${2:-""}
    
    if [[ "$bump_type" != "patch" && "$bump_type" != "minor" && "$bump_type" != "major" ]]; then
        echo -e "${RED}Invalid argument. Use: patch, minor, or major${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Bump type: $bump_type${NC}"
    
    # Calculate new version
    new_version=$(bump_version "$current_version" "$bump_type")
    echo -e "${BLUE}New version: $new_version${NC}"
    
    # Confirm with user
    echo ""
    read -p "Proceed with release v$new_version? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Release cancelled.${NC}"
        exit 0
    fi
    
    echo ""
    echo -e "${YELLOW}Updating version files...${NC}"
    
    # Update version.json
    update_version_in_file "version.json" "$current_version" "$new_version"
    
    # Update Directory.Build.props
    update_version_in_file "Directory.Build.props" "$current_version" "$new_version"
    # Also update assembly versions (with .0 suffix)
    sed -i.bak "s/${current_version}\.0/${new_version}.0/g" "Directory.Build.props" 2>/dev/null || true
    rm -f "Directory.Build.props.bak"
    
    # Generate changelog entry
    echo -e "${YELLOW}Generating changelog...${NC}"
    changelog_entry=$(generate_changelog_entry "v$new_version")
    
    # Update or create CHANGELOG.md
    if [ -f "CHANGELOG.md" ]; then
        # Insert new entry after the header
        temp_changelog=$(mktemp)
        {
            echo "# Changelog"
            echo ""
            echo "$changelog_entry"
            echo ""
            tail -n +3 CHANGELOG.md 2>/dev/null || true
        } > "$temp_changelog"
        mv "$temp_changelog" CHANGELOG.md
    else
        {
            echo "# Changelog"
            echo ""
            echo "$changelog_entry"
        } > CHANGELOG.md
    fi
    echo -e "${GREEN}✓ Updated CHANGELOG.md${NC}"
    
    # Stage all changes
    echo -e "${YELLOW}Staging changes...${NC}"
    git add version.json Directory.Build.props CHANGELOG.md
    
    # Commit changes
    commit_message="chore: release v$new_version"
    if [ -n "$custom_message" ]; then
        commit_message="$commit_message - $custom_message"
    fi
    
    echo -e "${YELLOW}Committing changes...${NC}"
    git commit -m "$commit_message"
    echo -e "${GREEN}✓ Created commit${NC}"
    
    # Create tag
    echo -e "${YELLOW}Creating tag v$new_version...${NC}"
    git tag -a "v$new_version" -m "Release v$new_version"
    echo -e "${GREEN}✓ Created tag v$new_version${NC}"
    
    # Push changes
    echo ""
    echo -e "${YELLOW}Ready to push changes and tag to remote.${NC}"
    read -p "Push to remote? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Pushing to remote...${NC}"
        git push origin "$current_branch"
        git push origin "v$new_version"
        echo -e "${GREEN}✓ Pushed changes and tag to remote${NC}"
        echo ""
        echo -e "${GREEN}🎉 Release v$new_version complete!${NC}"
        echo -e "${BLUE}GitHub Actions will now build and create the release.${NC}"
        echo -e "${BLUE}Check: https://github.com/mattjcowan/LinqPadCompiler/actions${NC}"
    else
        echo -e "${YELLOW}Changes committed and tagged locally.${NC}"
        echo -e "${YELLOW}To push later, run:${NC}"
        echo -e "${BLUE}  git push origin $current_branch${NC}"
        echo -e "${BLUE}  git push origin v$new_version${NC}"
    fi
}

# Run main function
main "$@"