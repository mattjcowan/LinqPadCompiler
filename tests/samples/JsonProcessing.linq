<Query Kind="Program">
  <NuGetReference>Newtonsoft.Json</NuGetReference>
  <Namespace>Newtonsoft.Json</Namespace>
  <Namespace>System.Dynamic</Namespace>
</Query>

void Main(string[] args)
{
    // Create a simple object
    var person = new Person
    {
        Name = args.Length > 0 ? args[0] : "John Doe",
        Age = args.Length > 1 && int.TryParse(args[1], out var age) ? age : 30,
        Email = args.Length > 2 ? args[2] : "john@example.com"
    };
    
    // Serialize to JSON
    var json = JsonConvert.SerializeObject(person, Newtonsoft.Json.Formatting.Indented);
    Console.WriteLine("Serialized JSON:");
    Console.WriteLine(json);
    
    // Deserialize back
    var deserializedPerson = JsonConvert.DeserializeObject<Person>(json);
    Console.WriteLine($"\nDeserialized: {deserializedPerson.Name}, Age: {deserializedPerson.Age}");
}

public class Person
{
    public string Name { get; set; }
    public int Age { get; set; }
    public string Email { get; set; }
}