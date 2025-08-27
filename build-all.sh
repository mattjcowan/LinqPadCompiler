#!/bin/bash

# Build script for all platforms - creates both lite and full variants

set -e

# Parse command line arguments
VARIANT="both"
while [[ $# -gt 0 ]]; do
    case $1 in
        --variant=*)
            VARIANT="${1#*=}"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--variant=lite|full|both]"
            echo "  lite: Build lite version (requires .NET SDK on target)"
            echo "  full: Build full version (bundles .NET SDK)"
            echo "  both: Build both variants (default)"
            exit 0
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Validate variant
if [[ "$VARIANT" != "lite" && "$VARIANT" != "full" && "$VARIANT" != "both" ]]; then
    echo "Error: variant must be 'lite', 'full', or 'both'"
    exit 1
fi

# Clean previous builds
rm -rf dist/
mkdir -p dist

echo "Building LinqPadCompiler ($VARIANT variant) for multiple platforms..."

# Define target platforms with SDK URLs (using builds.dotnet.microsoft.com)
DOTNET_VERSION="8.0.413"
declare -A platforms=(
    ["linux-x64"]="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_VERSION}/dotnet-sdk-${DOTNET_VERSION}-linux-x64.tar.gz"
    ["win-x64"]="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_VERSION}/dotnet-sdk-${DOTNET_VERSION}-win-x64.zip"
    ["osx-x64"]="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_VERSION}/dotnet-sdk-${DOTNET_VERSION}-osx-x64.tar.gz"
    ["osx-arm64"]="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_VERSION}/dotnet-sdk-${DOTNET_VERSION}-osx-arm64.tar.gz"
)

# Function to download and extract .NET SDK
download_sdk() {
    local platform=$1
    local sdk_url=$2
    local sdk_dir="dist/sdk-$platform"
    
    echo "  Downloading .NET SDK for $platform..."
    mkdir -p "$sdk_dir"
    
    # Determine archive extension and extraction method
    if [[ "$platform" == win-* ]]; then
        local archive_file="$sdk_dir/dotnet-sdk.zip"
        curl -fsSL "$sdk_url" -o "$archive_file"
        cd "$sdk_dir" && unzip -q dotnet-sdk.zip && rm dotnet-sdk.zip
    else
        local archive_file="$sdk_dir/dotnet-sdk.tar.gz"
        curl -fsSL "$sdk_url" -o "$archive_file"
        cd "$sdk_dir" && tar -xzf dotnet-sdk.tar.gz && rm dotnet-sdk.tar.gz
    fi
    cd - > /dev/null
    echo "  ✓ Downloaded .NET SDK to $sdk_dir"
}

# Function to build a variant
build_variant() {
    local variant=$1
    local platform=$2
    local sdk_url=$3
    
    echo "Building $variant variant for $platform..."
    
    # Determine executable extension
    exe_ext=""
    if [[ "$platform" == win-* ]]; then
        exe_ext=".exe"
    fi
    
    # Build self-contained single-file executable
    output_dir="dist/$variant-$platform"
    mkdir -p "$output_dir"
    
    dotnet publish src/LinqPadCompiler.csproj \
        -c Release \
        -r "$platform" \
        --self-contained true \
        -p:PublishSingleFile=true \
        -p:PublishTrimmed=true \
        -p:TrimMode=link \
        -p:IncludeNativeLibrariesForSelfExtract=true \
        -o "$output_dir"
    
    # Rename executable to simple name
    executable_name="linqpadcompiler$exe_ext"
    if [ -f "$output_dir/LinqPadCompiler$exe_ext" ]; then
        mv "$output_dir/LinqPadCompiler$exe_ext" "$output_dir/$executable_name"
    fi
    
    # For full variant, bundle .NET SDK
    if [ "$variant" == "full" ]; then
        echo "  Bundling .NET SDK..."
        download_sdk "$platform" "$sdk_url"
        
        # Copy SDK to output directory
        mkdir -p "$output_dir/dotnet"
        cp -r "dist/sdk-$platform/"* "$output_dir/dotnet/"
        
        # Create wrapper script that sets DOTNET_ROOT
        if [[ "$platform" == win-* ]]; then
            cat > "$output_dir/linqpadcompiler-wrapper.bat" << 'EOF'
@echo off
set DOTNET_ROOT=%~dp0dotnet
set PATH=%DOTNET_ROOT%;%PATH%
"%~dp0linqpadcompiler.exe" %*
EOF
            # Rename main executable and use wrapper
            mv "$output_dir/$executable_name" "$output_dir/linqpadcompiler-bin.exe"
            mv "$output_dir/linqpadcompiler-wrapper.bat" "$output_dir/$executable_name.bat"
        else
            cat > "$output_dir/linqpadcompiler-wrapper" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTNET_ROOT="$SCRIPT_DIR/dotnet"
export PATH="$DOTNET_ROOT:$PATH"
exec "$SCRIPT_DIR/linqpadcompiler-bin" "$@"
EOF
            chmod +x "$output_dir/linqpadcompiler-wrapper"
            # Rename main executable and use wrapper
            mv "$output_dir/$executable_name" "$output_dir/linqpadcompiler-bin"
            mv "$output_dir/linqpadcompiler-wrapper" "$output_dir/$executable_name"
        fi
    fi
    
    # Create compressed archive
    cd dist
    archive_name="linqpadcompiler-$variant-$platform"
    if [[ "$platform" == win-* ]]; then
        zip -r "$archive_name.zip" "$variant-$platform/"
    else
        tar -czf "$archive_name.tar.gz" "$variant-$platform/"
    fi
    cd ..
    
    # Show file size
    total_size=$(du -sh "$output_dir" | cut -f1)
    echo "  ✓ Built $variant variant ($total_size)"
}

# Build for each platform
for platform in "${!platforms[@]}"; do
    sdk_url="${platforms[$platform]}"
    
    if [[ "$VARIANT" == "lite" || "$VARIANT" == "both" ]]; then
        build_variant "lite" "$platform" "$sdk_url"
    fi
    
    if [[ "$VARIANT" == "full" || "$VARIANT" == "both" ]]; then
        build_variant "full" "$platform" "$sdk_url"
    fi
done

# Clean up SDK downloads
rm -rf dist/sdk-*

echo ""
echo "All builds completed successfully!"
echo "Files created in dist/:"
ls -la dist/*.tar.gz dist/*.zip 2>/dev/null || true