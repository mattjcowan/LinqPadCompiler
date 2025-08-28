# Changelog

## [1.0.2] - 2025-01-28

### Added
- System-wide installation support for Linux/macOS (`--system` flag)
- System-wide installation support for Windows (`-System` flag)
- Uninstall scripts for both platforms (`uninstall.sh` and `uninstall.ps1`)
- Support for both user and system-wide uninstallation
- Version management system (`version.json` and `Directory.Build.props`)
- Release automation scripts (`release.sh` and `release.ps1`)
- Automatic changelog generation from commit messages

### Changed
- Install scripts now detect and inform about existing installations
- Enhanced installation feedback with cross-installation detection

## [1.0.1] - 2025-01-27

### Added
- PowerShell installer for Windows (`install.ps1`)
- Auto-detection of .NET SDK availability
- Intelligent variant selection based on environment
- Cross-platform installation script improvements

### Changed
- Installation scripts now recommend appropriate variant
- Improved error handling and user feedback

## [1.0.0] - 2025-01-26

### Added
- Initial release of LinqPadCompiler
- Command-line compilation of LINQPad scripts to executables
- Support for NuGet package references
- Dual-variant distribution:
  - Lite variant (~10MB, requires .NET SDK)
  - Full variant (~200MB, includes bundled .NET SDK)
- Multiple output types:
  - CompiledFolder (default)
  - SingleFileExe
  - SingleFileDll
  - Dll
- Linux/macOS installation script (`install.sh`)
- Support for multiple platforms:
  - linux-x64
  - win-x64
  - osx-x64
  - osx-arm64

### Features
- Parse LINQPad `.linq` files
- Extract and install NuGet packages
- Generate C# projects from LINQPad scripts
- Compile to various output formats
- Preserve original script functionality