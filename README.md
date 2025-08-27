# LinqPadCompiler

A command-line tool that compiles LINQPad scripts (`.linq` files) into standalone executable applications.

## Quick Installation

### Automatic Installation (Recommended)

```bash
# Auto-detects your platform and .NET SDK availability
curl -fsSL https://raw.githubusercontent.com/mattjcowan/LinqPadCompiler/main/install.sh | bash
```

### Choose Your Variant

```bash
# Lite: ~10MB download, requires .NET SDK on target machine
curl -fsSL https://raw.githubusercontent.com/mattjcowan/LinqPadCompiler/main/install.sh | bash -s -- --variant=lite

# Full: ~200MB download, completely self-contained (no .NET SDK required)
curl -fsSL https://raw.githubusercontent.com/mattjcowan/LinqPadCompiler/main/install.sh | bash -s -- --variant=full
```

### Manual Installation

1. Download the appropriate variant and platform from [Releases](https://github.com/mattjcowan/LinqPadCompiler/releases):
   - **Lite variants**: `linqpadcompiler-lite-{platform}.{ext}` (~10MB)
   - **Full variants**: `linqpadcompiler-full-{platform}.{ext}` (~200MB)
2. Extract the archive
3. Move the `linqpadcompiler` binary to a directory in your PATH

### Available Variants

| Variant  | Download Size | Extracted Size | .NET SDK Required | Best For                               |
| -------- | ------------- | -------------- | ----------------- | -------------------------------------- |
| **Lite** | ~10MB         | ~30MB          | ✅ Yes            | Developers, CI/CD pipelines            |
| **Full** | ~200MB        | ~600MB         | ❌ No             | Production servers, clean environments |

## Usage

### Basic Examples

Compile a LINQPad script to a runnable application:

```bash
linqpadcompiler --linq-file script.linq --output-dir ./output --create
```

Create a single-file executable:

```bash
linqpadcompiler --linq-file script.linq --output-dir ./output --output-type SingleFileDll --create
```

Generate source code only (no compilation):

```bash
linqpadcompiler --linq-file script.linq --output-dir ./output --output-type SourceFolderOnly --create
```

### Command-Line Options

```
Usage:
  LinqPadCompiler [options]

Options:
  -f, --linq-file <linq-file> (REQUIRED)                             Path to the LINQPad .linq file
  -o, --output-dir <output-dir> (REQUIRED)                           Output directory for results
  -t, --output-type <CompiledFolder|SingleFileDll|SourceFolderOnly>  Output type for compilation [default: CompiledFolder]
  -c, --create                                                       Create the output directory if it does not exist [default: False]
  -v, --verbose                                                      Enable verbose output [default: False]
  --version                                                          Show version information
  -?, -h, --help                                                     Show help and usage information
```

### Output Types

- **CompiledFolder** (default): Creates a folder with the compiled application and all dependencies
- **SingleFileDll**: Creates a single, self-contained executable file (trimmed)
- **SourceFolderOnly**: Generates only the C# source code without compilation

## Supported LINQPad Features

### Query Types

- ✅ **C# Program** - Full program compilation with `Main` method
- ❌ C# Expression - Not supported
- ❌ C# Statement(s) - Not supported

### Dependencies

- ✅ **NuGet Packages** - Automatically installed during compilation
- ✅ **Namespaces** - Imported as using statements
- ✅ **Nested Classes** - Extracted to top-level scope
- ✅ **File I/O Operations**
- ✅ **Command-line Arguments**

### Example LINQPad Script

```xml
<Query Kind="Program">
  <NuGetReference>Newtonsoft.Json</NuGetReference>
  <Namespace>Newtonsoft.Json</Namespace>
  <Namespace>System.IO</Namespace>
</Query>

void Main(string[] args)
{
    var data = new { Name = "John", Age = 30 };
    var json = JsonConvert.SerializeObject(data, Formatting.Indented);
    Console.WriteLine(json);

    if (args.Length > 0)
    {
        Console.WriteLine($"First argument: {args[0]}");
    }
}
```

## Development

### Building from Source

```bash
# Clone the repository
git clone https://github.com/mattjcowan/LinqPadCompiler.git
cd LinqPadCompiler

# Quick development build (current platform)
dotnet build -c Release

# Build all platforms and variants
./build-all.sh

# Build specific platform
./build-linux-x64.sh --variant=lite
./build-win-x64.sh --variant=full
./build-osx-x64.sh --variant=both
./build-osx-arm64.sh --help
```

### Build Script Options

Each platform-specific script supports:

```bash
# Available build scripts
./build-linux-x64.sh    # Linux x86_64
./build-win-x64.sh       # Windows x86_64
./build-osx-x64.sh       # macOS Intel
./build-osx-arm64.sh     # macOS Apple Silicon
./build-all.sh           # All platforms

# Variant options
--variant=lite           # Lite version (default for individual scripts)
--variant=full           # Full version with bundled .NET SDK
--variant=both           # Build both variants (build-all.sh only, default)
--help                   # Show usage information
```

### Running Tests

```bash
# Run the core compiler test suite
./tests/run-tests.sh

# Test both lite and full packaged variants
./tests/run-tests.sh --test-variants

# Test installation process end-to-end
./tests/test-installation.sh

# Quick argument verification test
./tests/verify-args.sh
```

### Project Structure

```
LinqPadCompiler/
├── src/
│   ├── Program.cs              # Main application code
│   └── LinqPadCompiler.csproj  # Project file
├── tests/
│   ├── samples/                # Sample .linq files for testing
│   ├── run-tests.sh           # Test runner script (supports --test-variants)
│   ├── test-installation.sh   # End-to-end installation testing
│   └── verify-args.sh         # Command-line argument verification
├── build-all.sh               # Multi-platform build script
├── build-linux-x64.sh         # Linux x64 build script
├── build-win-x64.sh           # Windows x64 build script
├── build-osx-x64.sh           # macOS Intel build script
├── build-osx-arm64.sh         # macOS Apple Silicon build script
├── install.sh                 # Cross-platform installation script
└── .github/workflows/         # CI/CD automation
```

### Push a new Release

#### Test without creating a tag

1. Commit the fix
2. Go to GitHub → Actions → "Build and Release" workflow
3. Click "Run workflow" and manually trigger it
4. If successful, then create the real tag

```bash
git add .
git commit -m "Fix Windows PowerShell syntax in GitHub Actions"
git push origin main
# Then manually trigger workflow on GitHub to test
# Only create tag after verifying it works
```

#### Create a patch release

```bash
git add .
git commit -m "Fix Windows PowerShell syntax in GitHub Actions"
git tag v1.0.1
git push origin main
git push origin v1.0.1
```

### Development Workflow

1. **Make changes** to source code
2. **Test locally**: `./tests/run-tests.sh --test-variants`
3. **Test installation**: `./tests/test-installation.sh`
4. **Build specific platform**: `./build-linux-x64.sh --variant=lite`
5. **Build all variants**: `./build-all.sh --variant=both`
6. **Commit and tag**: Triggers automated CI/CD release

## How It Works

1. **Parse** the LINQPad `.linq` file to extract metadata and code
2. **Transform** the code to make `Main` methods static and extract nested classes
3. **Generate** a standard .NET project with proper dependencies
4. **Compile** using `dotnet publish` with specified output type
5. **Package** the result as executable application

## Requirements

- ✅ No .NET SDK required for end users (self-contained executables)
- ✅ Cross-platform support (Linux, Windows, macOS)
- ✅ Automatic dependency resolution
- ✅ Single-file deployment option

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with .NET 8 (LTS) and System.CommandLine
- Inspired by the need to run LINQPad scripts in CI/CD environments
- Uses Roslyn for C# code analysis and transformation
