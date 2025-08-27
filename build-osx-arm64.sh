#!/bin/bash

# Build script for macOS ARM64 (Apple Silicon) - supports both lite and full variants

set -e

# Parse command line arguments
VARIANT="lite"
while [[ $# -gt 0 ]]; do
    case $1 in
        --variant=*)
            VARIANT="${1#*=}"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--variant=lite|full]"
            echo "  lite: Build lite version (requires .NET SDK on target) - default"
            echo "  full: Build full version (bundles .NET SDK)"
            exit 0
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Validate variant
if [[ "$VARIANT" != "lite" && "$VARIANT" != "full" ]]; then
    echo "Error: variant must be 'lite' or 'full'"
    exit 1
fi

PLATFORM="osx-arm64"
DOTNET_VERSION="8.0.413"
OUTPUT_DIR="dist/$VARIANT-$PLATFORM"

echo "Building LinqPadCompiler ($VARIANT variant) for $PLATFORM..."

# Clean and create output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Build self-contained single-file executable
dotnet publish src/LinqPadCompiler.csproj \
    -c Release \
    -r "$PLATFORM" \
    --self-contained true \
    -p:PublishSingleFile=true \
    -p:PublishTrimmed=true \
    -p:TrimMode=link \
    -p:IncludeNativeLibrariesForSelfExtract=true \
    -o "$OUTPUT_DIR"

# Rename executable to simple name
mv "$OUTPUT_DIR/LinqPadCompiler" "$OUTPUT_DIR/linqpadcompiler"

# For full variant, bundle .NET SDK
if [ "$VARIANT" == "full" ]; then
    echo "Bundling .NET SDK..."
    
    # Download SDK
    SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_VERSION}/dotnet-sdk-${DOTNET_VERSION}-osx-arm64.tar.gz"
    SDK_DIR="dist/sdk-temp"
    mkdir -p "$SDK_DIR"
    
    curl -fsSL "$SDK_URL" -o "$SDK_DIR/dotnet-sdk.tar.gz"
    cd "$SDK_DIR" && tar -xzf dotnet-sdk.tar.gz && rm dotnet-sdk.tar.gz
    cd - > /dev/null
    
    # Copy SDK to output directory
    mkdir -p "$OUTPUT_DIR/dotnet"
    cp -r "$SDK_DIR/"* "$OUTPUT_DIR/dotnet/"
    
    # Create wrapper script
    cat > "$OUTPUT_DIR/linqpadcompiler-wrapper" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTNET_ROOT="$SCRIPT_DIR/dotnet"
export PATH="$DOTNET_ROOT:$PATH"
exec "$SCRIPT_DIR/linqpadcompiler-bin" "$@"
EOF
    chmod +x "$OUTPUT_DIR/linqpadcompiler-wrapper"
    
    # Rename main executable and use wrapper
    mv "$OUTPUT_DIR/linqpadcompiler" "$OUTPUT_DIR/linqpadcompiler-bin"
    mv "$OUTPUT_DIR/linqpadcompiler-wrapper" "$OUTPUT_DIR/linqpadcompiler"
    
    # Clean up
    rm -rf "$SDK_DIR"
fi

# Create compressed archive
cd dist
tar -czf "linqpadcompiler-$VARIANT-$PLATFORM.tar.gz" "$VARIANT-$PLATFORM/"
cd ..

# Show results
TOTAL_SIZE=$(du -sh "$OUTPUT_DIR" | cut -f1)
ARCHIVE_SIZE=$(du -h "dist/linqpadcompiler-$VARIANT-$PLATFORM.tar.gz" | cut -f1)

echo "✓ Build complete!"
echo "  Directory: $OUTPUT_DIR ($TOTAL_SIZE)"
echo "  Archive: dist/linqpadcompiler-$VARIANT-$PLATFORM.tar.gz ($ARCHIVE_SIZE)"