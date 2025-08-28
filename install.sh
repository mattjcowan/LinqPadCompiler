#!/bin/bash

# LinqPadCompiler Installation Script
# Usage: curl -fsSL https://raw.githubusercontent.com/mattjcowan/LinqPadCompiler/main/install.sh | bash
# Options: --variant=lite|full (auto-detects if not specified)

set -e

# Parse command line arguments
VARIANT=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --variant=*)
            VARIANT="${1#*=}"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--variant=lite|full]"
            echo ""
            echo "Variants:"
            echo "  lite: ~10MB download, requires .NET SDK on target machine"
            echo "  full: ~200MB download, completely self-contained (no .NET SDK required)"
            echo ""
            echo "If --variant is not specified, the script will:"
            echo "1. Check if .NET SDK is available"
            echo "2. Recommend the appropriate variant"
            echo "3. Install the lite variant by default (with warning if .NET SDK missing)"
            exit 0
            ;;
        *)
            echo "Unknown parameter: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO="mattjcowan/LinqPadCompiler"
BINARY_NAME="linqpadcompiler"
INSTALL_DIR="$HOME/.local/bin"

# Detect platform
detect_platform() {
    local os arch
    
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)
    
    case "$os" in
        linux*)
            os="linux"
            ;;
        darwin*)
            os="osx"
            ;;
        mingw*|msys*|cygwin*)
            os="win"
            ;;
        *)
            echo -e "${RED}Unsupported operating system: $os${NC}"
            exit 1
            ;;
    esac
    
    case "$arch" in
        x86_64|amd64)
            arch="x64"
            ;;
        arm64|aarch64)
            arch="arm64"
            ;;
        *)
            echo -e "${RED}Unsupported architecture: $arch${NC}"
            exit 1
            ;;
    esac
    
    echo "$os-$arch"
}

# Check if .NET SDK is available
check_dotnet_sdk() {
    if command -v dotnet >/dev/null 2>&1; then
        local version
        version=$(dotnet --version 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$version" ]; then
            echo "found:$version"
        else
            echo "not-found"
        fi
    else
        echo "not-found"
    fi
}

# Determine appropriate variant
determine_variant() {
    local dotnet_status
    
    if [ -n "$VARIANT" ]; then
        # Validate specified variant
        if [[ "$VARIANT" != "lite" && "$VARIANT" != "full" ]]; then
            echo -e "${RED}Error: variant must be 'lite' or 'full'${NC}" >&2
            exit 1
        fi
        echo "$VARIANT"
        return
    fi
    
    # Auto-detect appropriate variant
    echo -e "${YELLOW}Checking .NET SDK availability...${NC}" >&2
    dotnet_status=$(check_dotnet_sdk)
    
    if [[ "$dotnet_status" == found:* ]]; then
        local version="${dotnet_status#found:}"
        echo -e "${GREEN}✓ .NET SDK found: $version${NC}" >&2
        echo -e "${BLUE}Recommendation: Using 'lite' variant (~10MB)${NC}" >&2
        echo "lite"
    else
        echo -e "${YELLOW}⚠ .NET SDK not found${NC}" >&2
        echo -e "${BLUE}Recommendation: Use 'full' variant (~200MB) for complete self-contained installation${NC}" >&2
        echo -e "${YELLOW}Installing 'lite' variant by default. You can install the 'full' variant with:${NC}" >&2
        echo -e "${BLUE}curl -fsSL https://raw.githubusercontent.com/mattjcowan/LinqPadCompiler/main/install.sh | bash -s -- --variant=full${NC}" >&2
        echo "" >&2
        echo "lite"
    fi
}

# Get latest release info
get_latest_release() {
    curl -s "https://api.github.com/repos/$REPO/releases/latest" | 
        grep '"tag_name":' | 
        sed -E 's/.*"([^"]+)".*/\1/'
}

# Download and install
install_linqpadcompiler() {
    local platform version download_url archive_name variant
    
    platform=$(detect_platform)
    echo -e "${BLUE}Detected platform: $platform${NC}"
    
    # Determine variant to install
    variant=$(determine_variant)
    echo -e "${GREEN}Installing variant: $variant${NC}"
    echo ""
    
    # Get latest version
    echo -e "${YELLOW}Getting latest release information...${NC}"
    version=$(get_latest_release)
    if [ -z "$version" ]; then
        echo -e "${RED}Failed to get latest release information${NC}"
        exit 1
    fi
    echo -e "${BLUE}Latest version: $version${NC}"
    
    # Determine archive format and download URL
    if [[ "$platform" == win-* ]]; then
        archive_name="linqpadcompiler-$variant-$platform.zip"
        download_url="https://github.com/$REPO/releases/download/$version/$archive_name"
    else
        archive_name="linqpadcompiler-$variant-$platform.tar.gz"
        download_url="https://github.com/$REPO/releases/download/$version/$archive_name"
    fi
    
    echo -e "${YELLOW}Downloading $archive_name...${NC}"
    
    # Create temporary directory
    temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    # Download archive
    if ! curl -fsSL "$download_url" -o "$temp_dir/$archive_name"; then
        echo -e "${RED}Failed to download $download_url${NC}"
        echo -e "${RED}Please check if the release exists for your platform${NC}"
        exit 1
    fi
    
    # Extract archive
    echo -e "${YELLOW}Extracting archive...${NC}"
    cd "$temp_dir"
    if [[ "$archive_name" == *.zip ]]; then
        unzip -q "$archive_name"
    else
        tar -xzf "$archive_name"
    fi
    
    # Create install directory
    mkdir -p "$INSTALL_DIR"
    
    # Install binary (handle both lite and full variants)
    extracted_dir="$variant-$platform"
    binary_path="$extracted_dir/$BINARY_NAME"
    if [[ "$platform" == win-* ]]; then
        if [ "$variant" == "full" ]; then
            # Full variant uses .bat wrapper
            binary_path="$extracted_dir/$BINARY_NAME.bat"
        else
            # Lite variant uses .exe
            binary_path="$extracted_dir/$BINARY_NAME.exe"
        fi
    fi
    
    if [ ! -f "$binary_path" ]; then
        echo -e "${RED}Binary not found in archive: $binary_path${NC}"
        exit 1
    fi
    
    # For full variant, copy entire directory structure
    if [ "$variant" == "full" ]; then
        echo -e "${YELLOW}Installing full variant (includes bundled .NET SDK)...${NC}"
        cp -r "$extracted_dir/"* "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/$BINARY_NAME"*
        
        # Ensure dotnet directory has proper permissions
        if [ -d "$INSTALL_DIR/dotnet" ]; then
            chmod +x "$INSTALL_DIR/dotnet/dotnet"* 2>/dev/null || true
        fi
    else
        # For lite variant, copy just the binary
        cp "$binary_path" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/$BINARY_NAME"*
    fi
    
    echo -e "${GREEN}✓ LinqPadCompiler ($variant variant) installed successfully!${NC}"
    echo -e "${BLUE}Installation location: $INSTALL_DIR/$BINARY_NAME${NC}"
    
    # Show variant-specific information
    if [ "$variant" == "full" ]; then
        echo -e "${GREEN}✓ Bundled .NET SDK included - no additional dependencies required${NC}"
    else
        # Check if .NET SDK warning is needed
        dotnet_status=$(check_dotnet_sdk)
        if [[ "$dotnet_status" == "not-found" ]]; then
            echo -e "${YELLOW}⚠ Warning: .NET SDK is required to compile LINQPad scripts${NC}"
            echo -e "${YELLOW}  Install .NET SDK from: https://dotnet.microsoft.com/download${NC}"
            echo -e "${YELLOW}  Or use the full variant: curl ... | bash -s -- --variant=full${NC}"
        fi
    fi
    
    # Check if install directory is in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo -e "${YELLOW}Warning: $INSTALL_DIR is not in your PATH${NC}"
        echo -e "${YELLOW}Add this line to your shell profile (~/.bashrc, ~/.zshrc, etc.):${NC}"
        echo -e "${BLUE}export PATH=\"\$PATH:$INSTALL_DIR\"${NC}"
        echo ""
        echo -e "${YELLOW}Or run the tool directly with: $INSTALL_DIR/$BINARY_NAME${NC}"
    fi
    
    # Test installation
    echo -e "${YELLOW}Testing installation...${NC}"
    if "$INSTALL_DIR/$BINARY_NAME" --help >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Installation test passed!${NC}"
        echo ""
        echo -e "${GREEN}Usage examples:${NC}"
        echo -e "${BLUE}  $BINARY_NAME --linq-file script.linq --output-dir ./output --create${NC}"
        echo -e "${BLUE}  $BINARY_NAME --linq-file script.linq --output-dir ./output --output-type SingleFileDll${NC}"
    else
        echo -e "${RED}✗ Installation test failed${NC}"
        exit 1
    fi
}

# Main
echo -e "${GREEN}LinqPadCompiler Installation Script${NC}"
echo -e "${BLUE}Repository: https://github.com/$REPO${NC}"
echo ""

install_linqpadcompiler