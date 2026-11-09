using System.Text.Json;

namespace DepartureBoard.Core.Airports;

public sealed class AirportCatalog
{
    private readonly Dictionary<string, AirportProfile> airports = [];
    private readonly JsonElement cities;
    private readonly JsonElement destinations;
    private readonly JsonElement airlines;

    public AirportCatalog(string resourceDirectory)
    {

        ResourceDirectory = resourceDirectory;
        Strings = new StringCatalog(resourceDirectory);
        var order = ReadJson("LocationOrder.json");

        foreach (var entry in order.EnumerateArray())
        {
            var code = entry.GetString() ?? throw new InvalidDataException("Missing airport code.");
            airports.Add(
                code,
                new AirportProfile(ReadJson(Path.Combine("Locations", code + ".json")))
            );
        }

        cities = ReadJson("Cities.json");
        destinations = ReadJson("DestinationNames.json").Child("destinations");
        airlines = ReadJson("Airlines.json");
    }

    public string ResourceDirectory { get; }
    public StringCatalog Strings { get; }
    public IReadOnlyCollection<AirportProfile> Airports => airports.Values;

    public AirportProfile Get(string code)
    {

        return airports.TryGetValue(code, out var profile)
            ? profile
            : throw new ArgumentException("Choose a supported airport.", nameof(code));
    }

    public string Destination(string code, string language, string fallback)
    {

        var record = destinations.Child(code);
        return record.Text(language, record.Text("en", fallback));
    }

    public string City(string code, string language)
    {

        var record = cities.Child(code);
        return record.Text(language, record.Text("en", code));
    }

    public string Airline(string code)
    {

        return airlines.Child(code).Text("name", code);
    }

    private JsonElement ReadJson(string name)
    {

        using var document = JsonDocument.Parse(
            File.ReadAllText(Path.Combine(ResourceDirectory, name))
        );
        return document.RootElement.Clone();
    }
}
