<Query Kind="Program">
  <Namespace>System.IO</Namespace>
  <Namespace>System.Text</Namespace>
</Query>

void Main(string[] args)
{
    string filename = args.Length > 0 ? args[0] : "test_output.txt";
    string content = args.Length > 1 ? args[1] : "Default content from LINQPad compiled program";
    
    try
    {
        // Write to file
        var fullPath = Path.Combine(Directory.GetCurrentDirectory(), filename);
        File.WriteAllText(fullPath, content);
        Console.WriteLine($"Written to file: {fullPath}");
        
        // Read back and verify
        var readContent = File.ReadAllText(fullPath);
        Console.WriteLine($"File contains: {readContent}");
        
        // Get file info
        var fileInfo = new FileInfo(fullPath);
        Console.WriteLine($"File size: {fileInfo.Length} bytes");
        Console.WriteLine($"Created: {fileInfo.CreationTime}");
        
        // Cleanup
        File.Delete(fullPath);
        Console.WriteLine("File deleted successfully");
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"Error: {ex.Message}");
        Environment.Exit(1);
    }
}