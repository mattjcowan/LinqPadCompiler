#!/bin/bash

# Test script for LinqPadCompiler
# Don't exit on first error - we want to run all tests
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
COMPILER="$PROJECT_ROOT/src/bin/Release/net8.0/LinqPadCompiler"
SAMPLES_DIR="$SCRIPT_DIR/samples"
OUTPUT_DIR="$SCRIPT_DIR/output"
DIST_DIR="$PROJECT_ROOT/dist"

# Parse command line arguments
TEST_VARIANTS=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --test-variants)
            TEST_VARIANTS="true"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--test-variants]"
            echo "  --test-variants: Also test packaged lite and full variants"
            echo ""
            echo "For comprehensive testing including installation, also run:"
            echo "  ./tests/test-installation.sh"
            exit 0
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Build the compiler first
echo -e "${YELLOW}Building LinqPadCompiler...${NC}"
cd "$PROJECT_ROOT/src"
dotnet build -c Release --no-restore > /dev/null 2>&1
echo -e "${GREEN}✓ Compiler built successfully${NC}"

# Clean output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name=$1
    local linq_file=$2
    local output_type=$3
    local expected_output=$4
    local test_args="${5:-}"
    
    echo -e "\n${YELLOW}Testing: $test_name ($output_type)${NC}"
    
    local test_output_dir="$OUTPUT_DIR/${test_name}_${output_type}"
    
    # Compile the LINQ file
    echo "  Compiling $linq_file..."
    local compile_output
    if ! compile_output=$("$COMPILER" --linq-file "$linq_file" --output-dir "$test_output_dir" --output-type "$output_type" --create 2>&1); then
        echo -e "  ${RED}✗ Compilation failed${NC}"
        echo -e "  ${RED}Error: $compile_output${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
    echo -e "  ${GREEN}✓ Compilation successful${NC}"
    
    # For source-only output, skip execution
    if [ "$output_type" == "SourceFolderOnly" ]; then
        local source_file=$(find "$test_output_dir/src" -name "Program.cs" 2>/dev/null | head -1)
        if [ -n "$source_file" ] && [ -f "$source_file" ]; then
            echo -e "  ${GREEN}✓ Source files generated${NC}"
            ((TESTS_PASSED++))
            return 0
        else
            echo -e "  ${RED}✗ Source files not found${NC}"
            ((TESTS_FAILED++))
            return 1
        fi
    fi
    
    # Find the executable
    local executable=""
    local executable_name=$(basename "$linq_file" .linq)
    executable_name=$(echo "$executable_name" | sed 's/[^a-zA-Z0-9]/_/g')
    
    if [ "$output_type" == "SingleFileDll" ]; then
        executable=$(find "$test_output_dir/dist" -type f -executable -name "$executable_name" 2>/dev/null | head -1)
    else
        # For CompiledFolder, look for the native executable in the nested directory
        executable=$(find "$test_output_dir/dist/$executable_name" -type f -executable -name "$executable_name" 2>/dev/null | head -1)
        if [ -z "$executable" ]; then
            # Fallback to dll if no native executable
            local dll_path=$(find "$test_output_dir/dist/$executable_name" -type f -name "$executable_name.dll" 2>/dev/null | head -1)
            if [ -n "$dll_path" ]; then
                executable="dotnet $dll_path"
            fi
        fi
    fi
    
    if [ -z "$executable" ] || [ ! -f "${executable%% *}" ]; then
        echo -e "  ${RED}✗ Executable not found${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
    
    # Execute and check output
    echo "  Executing compiled program..."
    local actual_output
    if [ -n "$test_args" ]; then
        actual_output=$(cd "$test_output_dir/dist" && $executable $test_args 2>&1) || true
    else
        actual_output=$(cd "$test_output_dir/dist" && $executable 2>&1) || true
    fi
    
    if echo "$actual_output" | grep -q "$expected_output"; then
        echo -e "  ${GREEN}✓ Output matches expected: '$expected_output'${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗ Output mismatch${NC}"
        echo -e "  ${RED}Expected to contain: '$expected_output'${NC}"
        echo -e "  ${RED}Actual output: '$actual_output'${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to test --no-src cleanup functionality
run_test_with_cleanup() {
    local test_name=$1
    local linq_file=$2
    local output_type=$3
    local expected_output=$4
    local test_args="${5:-}"
    
    echo -e "\n${YELLOW}Testing: $test_name ($output_type with --no-src)${NC}"
    
    local test_output_dir="$OUTPUT_DIR/${test_name}_${output_type}"
    
    # Compile the LINQ file with --no-src
    echo "  Compiling $linq_file with --no-src..."
    local compile_output
    if ! compile_output=$("$COMPILER" --linq-file "$linq_file" --output-dir "$test_output_dir" --output-type "$output_type" --create --no-src 2>&1); then
        echo -e "  ${RED}✗ Compilation failed${NC}"
        echo -e "  ${RED}Error: $compile_output${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
    echo -e "  ${GREEN}✓ Compilation successful${NC}"
    
    # Check that src directory was cleaned up
    if [ -d "$test_output_dir/src" ]; then
        echo -e "  ${RED}✗ Source directory was not cleaned up${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
    echo -e "  ${GREEN}✓ Source directory cleaned up successfully${NC}"
    
    # Find the executable
    local executable=""
    local executable_name=$(basename "$linq_file" .linq)
    executable_name=$(echo "$executable_name" | sed 's/[^a-zA-Z0-9]/_/g')
    
    # For CompiledFolder, look for the native executable in the nested directory
    executable=$(find "$test_output_dir/dist/$executable_name" -type f -executable -name "$executable_name" 2>/dev/null | head -1)
    if [ -z "$executable" ]; then
        # Fallback to dll if no native executable
        local dll_path=$(find "$test_output_dir/dist/$executable_name" -type f -name "$executable_name.dll" 2>/dev/null | head -1)
        if [ -n "$dll_path" ]; then
            executable="dotnet $dll_path"
        fi
    fi
    
    if [ -z "$executable" ] || [ ! -f "${executable%% *}" ]; then
        echo -e "  ${RED}✗ Executable not found${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
    
    # Execute and check output
    echo "  Executing compiled program..."
    local actual_output
    if [ -n "$test_args" ]; then
        actual_output=$(cd "$test_output_dir/dist" && $executable $test_args 2>&1) || true
    else
        actual_output=$(cd "$test_output_dir/dist" && $executable 2>&1) || true
    fi
    
    if echo "$actual_output" | grep -q "$expected_output"; then
        echo -e "  ${GREEN}✓ Output matches expected and cleanup worked: '$expected_output'${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗ Output mismatch${NC}"
        echo -e "  ${RED}Expected to contain: '$expected_output'${NC}"
        echo -e "  ${RED}Actual output: '$actual_output'${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to test a packaged variant
test_variant_compilation() {
    local compiler_path=$1
    local variant_name=$2
    local test_output_dir="$OUTPUT_DIR/variant_${variant_name}_test"
    
    echo "  Testing $variant_name variant compilation..."
    
    # Test basic compilation
    local compile_output
    if ! compile_output=$("$compiler_path" --linq-file "$SAMPLES_DIR/HelloWorld.linq" --output-dir "$test_output_dir" --output-type CompiledFolder --create 2>&1); then
        echo -e "  ${RED}✗ $variant_name variant compilation failed${NC}"
        echo -e "  ${RED}Error: $compile_output${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
    
    # Test execution
    local executable=$(find "$test_output_dir/dist/HelloWorld" -type f -executable -name "HelloWorld" 2>/dev/null | head -1)
    if [ -z "$executable" ]; then
        local dll_path=$(find "$test_output_dir/dist/HelloWorld" -type f -name "HelloWorld.dll" 2>/dev/null | head -1)
        if [ -n "$dll_path" ]; then
            executable="dotnet $dll_path"
        fi
    fi
    
    if [ -z "$executable" ] || [ ! -f "${executable%% *}" ]; then
        echo -e "  ${RED}✗ $variant_name variant executable not found${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
    
    local actual_output
    actual_output=$(cd "$test_output_dir/dist" && $executable 2>&1) || true
    
    if echo "$actual_output" | grep -q "Hello, World!"; then
        echo -e "  ${GREEN}✓ $variant_name variant works correctly${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗ $variant_name variant output incorrect${NC}"
        echo -e "  ${RED}Expected: 'Hello, World!' but got: '$actual_output'${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 1: HelloWorld - Simple program
run_test "HelloWorld" "$SAMPLES_DIR/HelloWorld.linq" "CompiledFolder" "Hello, World!"
run_test "HelloWorld_SingleFile" "$SAMPLES_DIR/HelloWorld.linq" "SingleFileDll" "Hello, World!"

# Test 2: CommandLineArgs - Program with arguments
run_test "CommandLineArgs" "$SAMPLES_DIR/CommandLineArgs.linq" "CompiledFolder" "First argument was: test123" "test123 arg2 arg3"
run_test "CommandLineArgs_NoArgs" "$SAMPLES_DIR/CommandLineArgs.linq" "CompiledFolder" "No arguments provided" ""

# Test 3: JsonProcessing - Program with NuGet dependency
run_test "JsonProcessing" "$SAMPLES_DIR/JsonProcessing.linq" "CompiledFolder" "Deserialized: Alice" "Alice 25 alice@test.com"
run_test "JsonProcessing_Default" "$SAMPLES_DIR/JsonProcessing.linq" "CompiledFolder" "Deserialized: John Doe" ""

# Test 4: FileOperations - File I/O operations
run_test "FileOperations" "$SAMPLES_DIR/FileOperations.linq" "CompiledFolder" "File deleted successfully" "tempfile.txt 'Test content'"

# Test 5: Source-only generation
run_test "SourceOnly" "$SAMPLES_DIR/HelloWorld.linq" "SourceFolderOnly" ""

# Test 6: --no-src option (cleanup source files)
run_test_with_cleanup "NoSrcCleanup" "$SAMPLES_DIR/HelloWorld.linq" "CompiledFolder" "Hello, World!"

# Test packaged variants if requested
if [ "$TEST_VARIANTS" == "true" ]; then
    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Testing Packaged Variants${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    # Check if variants exist
    PLATFORM="linux-x64"  # Assuming we're running on Linux
    LITE_DIR="$DIST_DIR/lite-$PLATFORM"
    FULL_DIR="$DIST_DIR/full-$PLATFORM"
    
    if [ ! -d "$LITE_DIR" ] || [ ! -d "$FULL_DIR" ]; then
        echo -e "${YELLOW}Building packaged variants first...${NC}"
        cd "$PROJECT_ROOT"
        ./build-linux-x64.sh --variant=both >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to build packaged variants${NC}"
            ((TESTS_FAILED++))
        fi
    fi
    
    # Test lite variant
    if [ -d "$LITE_DIR" ] && [ -f "$LITE_DIR/linqpadcompiler" ]; then
        echo -e "\n${YELLOW}Testing lite variant...${NC}"
        test_variant_compilation "$LITE_DIR/linqpadcompiler" "lite"
    else
        echo -e "${RED}✗ Lite variant not found${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Test full variant
    if [ -d "$FULL_DIR" ] && [ -f "$FULL_DIR/linqpadcompiler" ]; then
        echo -e "\n${YELLOW}Testing full variant...${NC}"
        test_variant_compilation "$FULL_DIR/linqpadcompiler" "full"
    else
        echo -e "${RED}✗ Full variant not found${NC}"
        ((TESTS_FAILED++))
    fi
fi

# Summary
echo -e "\n${YELLOW}========================================${NC}"
echo -e "${YELLOW}Test Results Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi