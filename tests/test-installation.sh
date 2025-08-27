#!/bin/bash

# Test script for installation process with both variants
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
SAMPLES_DIR="$SCRIPT_DIR/samples"
TEST_INSTALL_DIR="$SCRIPT_DIR/test-install"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Clean up function
cleanup() {
    echo -e "${YELLOW}Cleaning up test installations...${NC}"
    rm -rf "$TEST_INSTALL_DIR"
}

trap cleanup EXIT

echo -e "${GREEN}LinqPadCompiler Installation Testing${NC}"
echo -e "${BLUE}This will test the installation script with both variants${NC}"
echo ""

# Ensure we have built packages
echo -e "${YELLOW}Building packages if needed...${NC}"
cd "$PROJECT_ROOT"
if [ ! -d "dist/lite-linux-x64" ] || [ ! -d "dist/full-linux-x64" ]; then
    ./build-linux-x64.sh --variant=both >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to build packages${NC}"
        exit 1
    fi
fi

# Create mock GitHub release structure for testing
MOCK_RELEASE_DIR="$TEST_INSTALL_DIR/mock-release"
mkdir -p "$MOCK_RELEASE_DIR"

# Copy archives to mock release directory
cp "dist/linqpadcompiler-lite-linux-x64.tar.gz" "$MOCK_RELEASE_DIR/" 2>/dev/null || true
cp "dist/linqpadcompiler-full-linux-x64.tar.gz" "$MOCK_RELEASE_DIR/" 2>/dev/null || true

# Test function
test_installation() {
    local variant=$1
    local test_name="install_${variant}"
    local install_dir="$TEST_INSTALL_DIR/$test_name"
    
    echo -e "\n${YELLOW}Testing $variant variant installation...${NC}"
    
    mkdir -p "$install_dir"
    cd "$install_dir"
    
    # Extract the package manually (simulating successful download)
    local archive_name="linqpadcompiler-$variant-linux-x64.tar.gz"
    if [ ! -f "$MOCK_RELEASE_DIR/$archive_name" ]; then
        echo -e "${RED}✗ Archive not found: $archive_name${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
    
    tar -xzf "$MOCK_RELEASE_DIR/$archive_name"
    
    # Test the extracted binary
    local binary_path="$variant-linux-x64/linqpadcompiler"
    if [ ! -f "$binary_path" ]; then
        echo -e "${RED}✗ Binary not found: $binary_path${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
    
    # Make executable
    chmod +x "$binary_path"
    
    # Test help command
    echo "  Testing --help command..."
    local help_output
    help_output=$(./"$binary_path" --help 2>&1) || true
    
    if echo "$help_output" | grep -q "Usage:"; then
        echo -e "  ${GREEN}✓ Help command works${NC}"
    else
        echo -e "  ${RED}✗ Help command failed${NC}"
        echo -e "  ${RED}Output: $help_output${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
    
    # Test compilation
    echo "  Testing compilation with $variant variant..."
    local compile_output_dir="$install_dir/test-output"
    local compile_output
    compile_output=$(./"$binary_path" --linq-file "$SAMPLES_DIR/HelloWorld.linq" --output-dir "$compile_output_dir" --output-type CompiledFolder --create 2>&1)
    
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ Compilation successful${NC}"
        
        # Test execution
        local executable=$(find "$compile_output_dir/dist/HelloWorld" -type f -executable -name "HelloWorld" 2>/dev/null | head -1)
        if [ -z "$executable" ]; then
            local dll_path=$(find "$compile_output_dir/dist/HelloWorld" -type f -name "HelloWorld.dll" 2>/dev/null | head -1)
            if [ -n "$dll_path" ]; then
                executable="dotnet $dll_path"
            fi
        fi
        
        if [ -n "$executable" ] && [ -f "${executable%% *}" ]; then
            local exec_output
            exec_output=$(cd "$compile_output_dir/dist" && $executable 2>&1) || true
            
            if echo "$exec_output" | grep -q "Hello, World!"; then
                echo -e "  ${GREEN}✓ Execution successful - $variant variant works end-to-end${NC}"
                ((TESTS_PASSED++))
                return 0
            else
                echo -e "  ${RED}✗ Execution failed - unexpected output: $exec_output${NC}"
                ((TESTS_FAILED++))
                return 1
            fi
        else
            echo -e "  ${RED}✗ Executable not found after compilation${NC}"
            ((TESTS_FAILED++))
            return 1
        fi
    else
        echo -e "  ${RED}✗ Compilation failed${NC}"
        echo -e "  ${RED}Output: $compile_output${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test both variants
test_installation "lite"
test_installation "full"

# Test specific full variant features
echo -e "\n${YELLOW}Testing full variant specific features...${NC}"
FULL_DIR="$TEST_INSTALL_DIR/install_full/full-linux-x64"

if [ -d "$FULL_DIR/dotnet" ]; then
    echo -e "${GREEN}✓ Bundled .NET SDK found in full variant${NC}"
    
    # Test that the wrapper script sets DOTNET_ROOT
    wrapper_content=$(cat "$FULL_DIR/linqpadcompiler" 2>/dev/null || echo "")
    if echo "$wrapper_content" | grep -q "DOTNET_ROOT"; then
        echo -e "${GREEN}✓ Wrapper script sets DOTNET_ROOT${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Wrapper script doesn't set DOTNET_ROOT${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Verify dotnet executable exists
    if [ -f "$FULL_DIR/dotnet/dotnet" ]; then
        echo -e "${GREEN}✓ Bundled dotnet executable found${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Bundled dotnet executable not found${NC}"
        ((TESTS_FAILED++))
    fi
else
    echo -e "${RED}✗ Bundled .NET SDK not found in full variant${NC}"
    ((TESTS_FAILED++))
fi

# Summary
echo -e "\n${YELLOW}========================================${NC}"
echo -e "${YELLOW}Installation Test Results${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}All installation tests passed!${NC}"
    exit 0
fi