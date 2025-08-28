#!/bin/bash

# LinqPadCompiler Uninstallation Script
# Usage: ./uninstall.sh [--system]
# Or: curl -fsSL https://raw.githubusercontent.com/mattjcowan/LinqPadCompiler/main/uninstall.sh | bash

set -e

# Parse command line arguments
SYSTEM_UNINSTALL="false"
while [[ $# -gt 0 ]]; do
    case $1 in
        --system)
            SYSTEM_UNINSTALL="true"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--system]"
            echo ""
            echo "Options:"
            echo "  --system  Uninstall system-wide installation from /usr/local/bin (requires root/sudo)"
            echo "            Default: uninstalls from ~/.local/bin for current user only"
            echo ""
            echo "Examples:"
            echo "  # User uninstallation (default)"
            echo "  ./uninstall.sh"
            echo ""
            echo "  # System-wide uninstallation"
            echo "  sudo ./uninstall.sh --system"
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
BINARY_NAME="linqpadcompiler"

# Determine uninstallation directory based on --system flag
if [ "$SYSTEM_UNINSTALL" == "true" ]; then
    INSTALL_DIR="/usr/local/bin"
    # Check for root/sudo privileges
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: System-wide uninstallation requires root privileges${NC}"
        echo -e "${YELLOW}Please run with sudo:${NC}"
        echo -e "${BLUE}  sudo ./uninstall.sh --system${NC}"
        echo -e "${YELLOW}Or:${NC}"
        echo -e "${BLUE}  curl -fsSL https://raw.githubusercontent.com/mattjcowan/LinqPadCompiler/main/uninstall.sh | sudo bash -s -- --system${NC}"
        exit 1
    fi
else
    INSTALL_DIR="$HOME/.local/bin"
fi

# Main uninstallation
echo -e "${GREEN}LinqPadCompiler Uninstallation Script${NC}"
if [ "$SYSTEM_UNINSTALL" == "true" ]; then
    echo -e "${YELLOW}Uninstalling system-wide installation...${NC}"
else
    echo -e "${YELLOW}Uninstalling user installation...${NC}"
fi
echo ""

# Check if linqpadcompiler exists
if [ ! -f "$INSTALL_DIR/$BINARY_NAME" ]; then
    echo -e "${YELLOW}Warning: $BINARY_NAME not found in $INSTALL_DIR${NC}"
    echo -e "${YELLOW}Nothing to uninstall.${NC}"
    
    # Check if it exists in the other location
    if [ "$SYSTEM_UNINSTALL" == "true" ]; then
        if [ -f "$HOME/.local/bin/$BINARY_NAME" ]; then
            echo ""
            echo -e "${BLUE}Note: User installation found at $HOME/.local/bin/$BINARY_NAME${NC}"
            echo -e "${BLUE}To uninstall that, run: ./uninstall.sh${NC}"
        fi
    else
        if [ -f "/usr/local/bin/$BINARY_NAME" ]; then
            echo ""
            echo -e "${BLUE}Note: System-wide installation found at /usr/local/bin/$BINARY_NAME${NC}"
            echo -e "${BLUE}To uninstall that, run: sudo ./uninstall.sh --system${NC}"
        fi
    fi
    exit 0
fi

# Remove the binary and related files
echo -e "${YELLOW}Removing $BINARY_NAME from $INSTALL_DIR...${NC}"

# Remove main binary
rm -f "$INSTALL_DIR/$BINARY_NAME"

# For full variant, also remove the dotnet directory if it exists
if [ -d "$INSTALL_DIR/dotnet" ]; then
    echo -e "${YELLOW}Removing bundled .NET SDK...${NC}"
    rm -rf "$INSTALL_DIR/dotnet"
fi

# Remove any .dll, .pdb, and .runtimeconfig.json files that belong to linqpadcompiler
for file in "$INSTALL_DIR"/linqpadcompiler.* "$INSTALL_DIR"/LinqPadCompiler.*; do
    if [ -f "$file" ]; then
        rm -f "$file"
    fi
done

echo -e "${GREEN}✓ LinqPadCompiler has been uninstalled successfully!${NC}"

# Check if install directory is still in PATH
if [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo -e "${YELLOW}Note: $INSTALL_DIR is still in your PATH${NC}"
    if [ "$SYSTEM_UNINSTALL" != "true" ]; then
        echo -e "${YELLOW}You may want to remove it from your shell profile (~/.bashrc, ~/.zshrc, etc.)${NC}"
        echo -e "${YELLOW}Look for lines like: export PATH=\"\$PATH:$INSTALL_DIR\"${NC}"
    fi
fi

# Final confirmation
echo ""
if [ "$SYSTEM_UNINSTALL" == "true" ]; then
    echo -e "${BLUE}System-wide uninstallation complete.${NC}"
else
    echo -e "${BLUE}User uninstallation complete.${NC}"
fi