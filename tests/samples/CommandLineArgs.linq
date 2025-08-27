<Query Kind="Program" />

void Main(string[] args)
{
    if (args.Length == 0)
    {
        Console.WriteLine("No arguments provided");
        Environment.Exit(1);
    }
    
    Console.WriteLine($"Received {args.Length} arguments:");
    for (int i = 0; i < args.Length; i++)
    {
        Console.WriteLine($"  Arg[{i}]: {args[i]}");
    }
    
    // Echo back the first argument
    if (args.Length > 0)
    {
        Console.WriteLine($"First argument was: {args[0]}");
    }
}