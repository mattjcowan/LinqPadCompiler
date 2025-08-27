using System.CommandLine;
using System.Diagnostics;
using System.Diagnostics.CodeAnalysis;
using System.Text;
using System.Text.RegularExpressions;
using System.Xml.Serialization;
using LinqPadCompiler;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

var rootCommand = new RootCommand("Compile LINQPad scripts to executable applications");

var linqFileOption = new Option<FileInfo>(
    new[] { "--linq-file", "-f" },
    "Path to the LINQPad .linq file"
)
{
    IsRequired = true,
};
linqFileOption.AddValidator(result =>
{
    var file = result.GetValueOrDefault<FileInfo>();
    if (file != null && !file.Exists)
    {
        result.ErrorMessage = "The specified LINQ file does not exist.";
    }
    else if (file != null && !file.Extension.Equals(".linq", StringComparison.OrdinalIgnoreCase))
    {
        result.ErrorMessage = "File must be a .linq file.";
    }
});

var outputDirOption = new Option<DirectoryInfo>(
    new[] { "--output-dir", "-o" },
    "Output directory for results"
)
{
    IsRequired = true,
};

var outputTypeOption = new Option<OutputType>(
    new[] { "--output-type", "-t" },
    getDefaultValue: () => OutputType.CompiledFolder,
    "Output type for compilation"
);

var createOption = new Option<bool>(
    new[] { "--create", "-c" },
    getDefaultValue: () => false,
    "Create the output directory if it does not exist"
);

var verboseOption = new Option<bool>(
    new[] { "--verbose", "-v" },
    getDefaultValue: () => false,
    "Enable verbose output"
);

rootCommand.AddOption(linqFileOption);
rootCommand.AddOption(outputDirOption);
rootCommand.AddOption(outputTypeOption);
rootCommand.AddOption(createOption);
rootCommand.AddOption(verboseOption);

rootCommand.SetHandler(
    async (context) =>
    {
        var linqFile = context.ParseResult.GetValueForOption(linqFileOption)!;
        var outputDir = context.ParseResult.GetValueForOption(outputDirOption)!;
        var outputType = context.ParseResult.GetValueForOption(outputTypeOption);
        var create = context.ParseResult.GetValueForOption(createOption);
        var verbose = context.ParseResult.GetValueForOption(verboseOption);

        context.ExitCode = await ExecuteAsync(
            linqFile,
            outputDir,
            outputType,
            create,
            verbose,
            context.GetCancellationToken()
        );
    }
);

return await rootCommand.InvokeAsync(args);

static async Task<int> ExecuteAsync(
    FileInfo linqFile,
    DirectoryInfo outputDir,
    OutputType outputType,
    bool create,
    bool verbose,
    CancellationToken cancellationToken
)
{
    var logger = new ConsoleLogger(verbose);

    try
    {
        if (!outputDir.Exists)
        {
            if (create)
            {
                logger.LogVerbose($"Creating output directory: {outputDir.FullName}");
                outputDir.Create();
            }
            else
            {
                logger.LogError("Output directory does not exist. Use --create to create it.");
                return 1;
            }
        }

        logger.LogVerbose($"Processing LINQ file: {linqFile.FullName}");
        logger.LogVerbose($"Output directory: {outputDir.FullName}");
        logger.LogVerbose($"Output type: {outputType}");

        var script = await File.ReadAllTextAsync(linqFile.FullName, cancellationToken);
        var parser = new LinqPadParser(logger);
        var parseResult = parser.ParseLinqPadScript(script);

        if (!parseResult.Success)
        {
            logger.LogError($"Failed to parse LINQ script: {parseResult.Error}");
            return 1;
        }

        logger.LogInfo("Successfully parsed LINQPad script");

        var namespaces = DefaultNamespaces.GetDefaults();
        namespaces.UnionWith(parseResult.Query!.Namespaces);

        var nugetReferences = new HashSet<string>(
            parseResult.Query.NuGetReferences,
            StringComparer.OrdinalIgnoreCase
        );
        var scriptName = Path.GetFileNameWithoutExtension(linqFile.Name);

        var compiler = new LinqPadCompiler.LinqPadCompiler(logger);
        var compileResult = await compiler.CompileLinqPadScriptAsync(
            parseResult.Code!,
            namespaces.ToList(),
            nugetReferences.ToList(),
            scriptName,
            outputType,
            outputDir.FullName,
            cancellationToken
        );

        if (!compileResult.Success)
        {
            logger.LogError($"Compilation failed: {compileResult.Error}");
            return 1;
        }

        logger.LogSuccess($"Successfully compiled to: {outputDir.FullName}");
        return 0;
    }
    catch (OperationCanceledException)
    {
        logger.LogWarning("Operation was cancelled");
        return 130;
    }
    catch (Exception ex)
    {
        logger.LogError($"Unexpected error: {ex.Message}");
        if (verbose)
        {
            logger.LogError(ex.ToString());
        }
        return 1;
    }
}

namespace LinqPadCompiler
{
    public interface ILogger
    {
        void LogInfo(string message);
        void LogWarning(string message);
        void LogError(string message);
        void LogSuccess(string message);
        void LogVerbose(string message);
    }

    public class ConsoleLogger : ILogger
    {
        private readonly bool _verbose;

        public ConsoleLogger(bool verbose = false)
        {
            _verbose = verbose;
        }

        public void LogInfo(string message) => Console.WriteLine(message);

        public void LogWarning(string message) => Console.WriteLine($"[WARNING] {message}");

        public void LogError(string message) => Console.Error.WriteLine($"[ERROR] {message}");

        public void LogSuccess(string message) => Console.WriteLine($"[SUCCESS] {message}");

        public void LogVerbose(string message)
        {
            if (_verbose)
                Console.WriteLine($"[VERBOSE] {message}");
        }
    }

    public static class DefaultNamespaces
    {
        public static HashSet<string> GetDefaults() =>
            new(StringComparer.OrdinalIgnoreCase)
            {
                "System",
                "System.Collections",
                "System.Collections.Generic",
                "System.Data",
                "System.Diagnostics",
                "System.IO",
                "System.Linq",
                "System.Linq.Expressions",
                "System.Reflection",
                "System.Text",
                "System.Text.RegularExpressions",
                "System.Threading",
                "System.Threading.Tasks",
                "System.Transactions",
                "System.Xml",
                "System.Xml.Linq",
                "System.Xml.XPath",
            };
    }

    public record ParseResult(bool Success, LPQuery? Query, string? Code, string? Error)
    {
        public static ParseResult Failure(string error) => new(false, null, null, error);

        public static ParseResult Ok(LPQuery query, string code) => new(true, query, code, null);
    }

    public record CompileResult(bool Success, string? Error)
    {
        public static CompileResult Ok() => new(true, null);

        public static CompileResult Failure(string error) => new(false, error);
    }

    [XmlRoot("Query")]
    [DynamicallyAccessedMembers(DynamicallyAccessedMemberTypes.All)]
    public class LPQuery
    {
        public LPQuery()
        {
            Kind = "Program";
            NuGetReferences = new List<string>();
            Namespaces = new List<string>();
        }

        [XmlAttribute("Kind")]
        public string Kind { get; set; }

        [XmlElement("NuGetReference")]
        public List<string> NuGetReferences { get; set; }

        [XmlElement("Namespace")]
        public List<string> Namespaces { get; set; }
    }

    public class LinqPadParser
    {
        private readonly ILogger _logger;

        public LinqPadParser(ILogger logger)
        {
            _logger = logger;
        }

        [UnconditionalSuppressMessage("Trimming", "IL2026:Members annotated with 'RequiresUnreferencedCodeAttribute' require dynamic access otherwise can break functionality when trimming application code", Justification = "LPQuery is preserved with DynamicallyAccessedMembers")]
        public ParseResult ParseLinqPadScript(string script)
        {
            const string queryStartTag = "<Query";
            const string queryEndTag = "</Query>";
            const string querySelfClosingTag = "/>";

            var xmlStart = script.IndexOf(queryStartTag, StringComparison.Ordinal);
            if (xmlStart == -1)
            {
                return ParseResult.Failure(
                    "The LINQPad script format is not supported (missing <Query> header)."
                );
            }

            // Check for self-closing tag first
            var selfClosingEnd = script.IndexOf(querySelfClosingTag, xmlStart, StringComparison.Ordinal);
            var xmlEnd = script.IndexOf(queryEndTag, xmlStart, StringComparison.Ordinal);
            
            string xmlHeader;
            string code;
            
            if (selfClosingEnd != -1 && (xmlEnd == -1 || selfClosingEnd < xmlEnd))
            {
                // Self-closing tag
                xmlEnd = selfClosingEnd + querySelfClosingTag.Length;
                xmlHeader = script.Substring(xmlStart, xmlEnd - xmlStart);
                code = script.Substring(xmlEnd).TrimStart();
            }
            else if (xmlEnd != -1)
            {
                // Regular closing tag
                xmlEnd += queryEndTag.Length;
                xmlHeader = script.Substring(xmlStart, xmlEnd - xmlStart);
                code = script.Substring(xmlEnd).TrimStart();
            }
            else
            {
                return ParseResult.Failure(
                    "The LINQPad script format is not supported (missing Query closing tag)."
                );
            }

            try
            {
                var serializer = new XmlSerializer(typeof(LPQuery));
                using var reader = new StringReader(xmlHeader);
                var lpQuery = (LPQuery?)serializer.Deserialize(reader);

                if (lpQuery == null)
                {
                    return ParseResult.Failure("Failed to deserialize LINQPad query metadata.");
                }

                if (!string.Equals(lpQuery.Kind, "Program", StringComparison.OrdinalIgnoreCase))
                {
                    return ParseResult.Failure(
                        $"The LINQPad compiler only supports 'C# Program' type compilations. Found: {lpQuery.Kind}"
                    );
                }

                _logger.LogVerbose($"Parsed query kind: {lpQuery.Kind}");
                _logger.LogVerbose($"Found {lpQuery.NuGetReferences.Count} NuGet references");
                _logger.LogVerbose($"Found {lpQuery.Namespaces.Count} namespaces");

                return ParseResult.Ok(lpQuery, code);
            }
            catch (Exception ex)
            {
                return ParseResult.Failure(
                    $"The LINQPad script format and/or contents are not supported: {ex.Message}"
                );
            }
        }
    }

    public enum OutputType
    {
        SingleFileDll,
        SourceFolderOnly,
        CompiledFolder,
    }

    public class LinqPadCompiler
    {
        private readonly ILogger _logger;
        private static readonly Regex SanitizeRegex = new(@"[^\w]", RegexOptions.Compiled);

        public LinqPadCompiler(ILogger logger)
        {
            _logger = logger;
        }

        public static string SanitizeName(string name)
        {
            return SanitizeRegex.Replace(name, "_");
        }

        public async Task<CompileResult> CompileLinqPadScriptAsync(
            string code,
            List<string> namespaces,
            List<string> nugetReferences,
            string scriptName,
            OutputType outputType,
            string outputPath,
            CancellationToken cancellationToken = default
        )
        {
            try
            {
                var sanitizedScriptName = SanitizeName(scriptName);
                var srcDir = Path.Combine(outputPath, "src", sanitizedScriptName);
                var distDir = Path.Combine(outputPath, "dist", sanitizedScriptName);

                await PrepareDirectoriesAsync(srcDir, distDir, cancellationToken);

                var csprojPath = Path.Combine(srcDir, $"{sanitizedScriptName}.csproj");
                var programPath = Path.Combine(srcDir, "Program.cs");

                code = WrapInProgramClass(code);
                code = NestedClassExtractor.ExtractNestedClasses(code);

                await WriteProgramFileAsync(
                    programPath,
                    namespaces,
                    sanitizedScriptName,
                    code,
                    cancellationToken
                );
                await WriteProjectFileAsync(csprojPath, sanitizedScriptName, cancellationToken);

                if (!await AddNuGetPackagesAsync(nugetReferences, srcDir, cancellationToken))
                {
                    return CompileResult.Failure("Failed to add NuGet packages");
                }

                _logger.LogInfo($"Successfully generated source to {srcDir}");

                if (outputType == OutputType.SourceFolderOnly)
                {
                    return CompileResult.Ok();
                }

                var buildArgs = GetBuildArguments(outputType, distDir);
                var processResult = await RunProcessAsync(
                    "dotnet",
                    buildArgs,
                    srcDir,
                    cancellationToken
                );

                if (!processResult.Success)
                {
                    return CompileResult.Failure(processResult.Error ?? "Build failed");
                }

                _logger.LogInfo($"Successfully compiled script to {distDir}");
                return CompileResult.Ok();
            }
            catch (Exception ex)
            {
                return CompileResult.Failure($"Unexpected error during compilation: {ex.Message}");
            }
        }

        private async Task PrepareDirectoriesAsync(
            string srcDir,
            string distDir,
            CancellationToken cancellationToken
        )
        {
            await Task.Run(
                () =>
                {
                    if (Directory.Exists(srcDir))
                    {
                        _logger.LogVerbose($"Cleaning existing source directory: {srcDir}");
                        Directory.Delete(srcDir, true);
                    }
                    if (Directory.Exists(distDir))
                    {
                        _logger.LogVerbose($"Cleaning existing distribution directory: {distDir}");
                        Directory.Delete(distDir, true);
                    }
                    Directory.CreateDirectory(srcDir);
                    Directory.CreateDirectory(distDir);
                },
                cancellationToken
            );
        }

        private static string WrapInProgramClass(string code)
        {
            // Make Main method static if it exists
            code = MakeMainStatic(code);
            
            return $@"
public class Program
{{
    {code}
}}
";
        }
        
        private static string MakeMainStatic(string code)
        {
            // Simple regex to make Main method static if it isn't already
            var mainPattern = @"(\s*)(void|Task|async\s+Task|async\s+void)\s+Main\s*\(";
            var mainReplacement = "$1static $2 Main(";
            
            // Check if Main is already static
            if (!System.Text.RegularExpressions.Regex.IsMatch(code, @"\bstatic\s+(void|Task|async\s+Task|async\s+void)\s+Main\s*\("))
            {
                code = System.Text.RegularExpressions.Regex.Replace(code, mainPattern, mainReplacement);
            }
            
            return code;
        }

        private async Task WriteProgramFileAsync(
            string path,
            List<string> namespaces,
            string namespaceName,
            string code,
            CancellationToken cancellationToken
        )
        {
            var content = new StringBuilder();
            foreach (var ns in namespaces.Distinct().OrderBy(n => n))
            {
                content.AppendLine($"using {ns};");
            }
            content.AppendLine();
            content.AppendLine($"namespace {namespaceName};");
            content.AppendLine();
            content.AppendLine(code);

            await File.WriteAllTextAsync(path, content.ToString(), cancellationToken);
            _logger.LogVerbose($"Written Program.cs to {path}");
        }

        private async Task WriteProjectFileAsync(
            string path,
            string assemblyName,
            CancellationToken cancellationToken
        )
        {
            var projectContent =
                $@"<Project Sdk=""Microsoft.NET.Sdk"">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <LangVersion>latest</LangVersion>
    <Nullable>enable</Nullable>
    <AssemblyName>{assemblyName}</AssemblyName>
    <RootNamespace>{assemblyName}</RootNamespace>
    <PublishAot>false</PublishAot>
  </PropertyGroup>
</Project>";

            await File.WriteAllTextAsync(path, projectContent, cancellationToken);
            _logger.LogVerbose($"Written project file to {path}");
        }

        private async Task<bool> AddNuGetPackagesAsync(
            List<string> packages,
            string workingDir,
            CancellationToken cancellationToken
        )
        {
            foreach (var pkg in packages.Distinct())
            {
                _logger.LogVerbose($"Adding NuGet package: {pkg}");
                var result = await RunProcessAsync(
                    "dotnet",
                    $"add package \"{pkg}\"",
                    workingDir,
                    cancellationToken
                );

                if (!result.Success)
                {
                    _logger.LogError($"Failed to add NuGet package {pkg}: {result.Error}");
                    return false;
                }
            }
            return true;
        }

        private static string GetBuildArguments(OutputType outputType, string outputDir)
        {
            return outputType switch
            {
                OutputType.SingleFileDll =>
                    $"publish -c Release -r linux-x64 --self-contained true "
                        + $"/p:PublishSingleFile=true /p:PublishTrimmed=true /p:TrimMode=link -o \"{outputDir}\"",
                OutputType.CompiledFolder =>
                    $"publish -c Release -r linux-x64 --self-contained false -o \"{outputDir}\"",
                _ => string.Empty,
            };
        }

        private async Task<ProcessResult> RunProcessAsync(
            string fileName,
            string arguments,
            string workingDir,
            CancellationToken cancellationToken
        )
        {
            try
            {
                var psi = new ProcessStartInfo(fileName, arguments)
                {
                    WorkingDirectory = workingDir,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                };

                using var proc = Process.Start(psi);
                if (proc == null)
                {
                    return ProcessResult.Failure("Could not start process");
                }

                var outputTask = proc.StandardOutput.ReadToEndAsync();
                var errorTask = proc.StandardError.ReadToEndAsync();

                await proc.WaitForExitAsync(cancellationToken);

                var output = await outputTask;
                var error = await errorTask;

                if (proc.ExitCode != 0)
                {
                    return ProcessResult.Failure(
                        $"Process failed with exit code {proc.ExitCode}\n{error}\n{output}"
                    );
                }

                _logger.LogVerbose($"Process completed successfully: {fileName} {arguments}");
                return ProcessResult.Ok();
            }
            catch (Exception ex)
            {
                return ProcessResult.Failure($"Exception running process: {ex.Message}");
            }
        }

        private record ProcessResult(bool Success, string? Error)
        {
            public static ProcessResult Ok() => new(true, null);

            public static ProcessResult Failure(string error) => new(false, error);
        }
    }

    public static class NestedClassExtractor
    {
        public static string ExtractNestedClasses(string code)
        {
            try
            {
                var tree = CSharpSyntaxTree.ParseText(code);
                var root = tree.GetCompilationUnitRoot();

                var nestedClasses = FindNestedClasses(root);
                if (!nestedClasses.Any())
                {
                    return code;
                }

                var newRoot = RemoveNestedClasses(root, nestedClasses);
                newRoot = AddClassesToOuterScope(newRoot, nestedClasses);

                return newRoot.NormalizeWhitespace().ToFullString();
            }
            catch
            {
                return code;
            }
        }

        private static List<(
            ClassDeclarationSyntax Parent,
            ClassDeclarationSyntax Nested
        )> FindNestedClasses(CompilationUnitSyntax root)
        {
            return root.DescendantNodes()
                .OfType<ClassDeclarationSyntax>()
                .SelectMany(parent =>
                    parent
                        .Members.OfType<ClassDeclarationSyntax>()
                        .Select(nested => (Parent: parent, Nested: nested))
                )
                .ToList();
        }

        private static CompilationUnitSyntax RemoveNestedClasses(
            CompilationUnitSyntax root,
            List<(ClassDeclarationSyntax Parent, ClassDeclarationSyntax Nested)> nestedClasses
        )
        {
            var newRoot = root;
            var parentsToUpdate = new HashSet<ClassDeclarationSyntax>(
                nestedClasses.Select(x => x.Parent)
            );

            foreach (var parent in parentsToUpdate)
            {
                var nestedToRemove = parent.Members.OfType<ClassDeclarationSyntax>().ToList();
                if (nestedToRemove.Any())
                {
                    var newParent = parent.RemoveNodes(
                        nestedToRemove,
                        SyntaxRemoveOptions.KeepNoTrivia
                    );
                    if (newParent != null)
                    {
                        newRoot = newRoot.ReplaceNode(parent, newParent);
                    }
                }
            }

            return newRoot;
        }

        private static CompilationUnitSyntax AddClassesToOuterScope(
            CompilationUnitSyntax root,
            List<(ClassDeclarationSyntax Parent, ClassDeclarationSyntax Nested)> nestedClasses
        )
        {
            var newRoot = root;

            foreach (var (parent, nested) in nestedClasses)
            {
                var parentNamespace = parent
                    .Ancestors()
                    .OfType<NamespaceDeclarationSyntax>()
                    .FirstOrDefault();

                if (parentNamespace != null)
                {
                    var newNamespace = parentNamespace.AddMembers(nested);
                    newRoot = newRoot.ReplaceNode(parentNamespace, newNamespace);
                }
                else
                {
                    newRoot = newRoot.AddMembers(nested);
                }
            }

            return newRoot;
        }
    }
}
