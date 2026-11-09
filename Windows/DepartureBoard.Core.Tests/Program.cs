using DepartureBoard.Core.Airports;
using DepartureBoard.Core.Flights;
using DepartureBoard.Core.Runtime;
using DepartureBoard.Core.Settings;

var resources = Path.GetFullPath(args.ElementAtOrDefault(0) ?? "Resources");
var catalog = new AirportCatalog(resources);
var now = DateTimeOffset.UtcNow;
var assertions = 0;

void Check(bool condition, string message)
{

    if (!condition)
    {
        throw new InvalidOperationException(message);
    }

    assertions++;
}

void Reject(Action action, string message)
{

    try
    {
        action();
    }
    catch (ArgumentException)
    {
        assertions++;
        return;
    }

    throw new InvalidOperationException(message);
}

Check(catalog.Airports.Count == 40, "Expected all 40 airport profiles.");
Reject(() => catalog.Get("INVALID"), "Unsupported codes must not select an airport.");

foreach (var airport in catalog.Airports)
{
    foreach (var language in new[] { "en", airport.Language })
    {
        var rows = SampleSchedule.Rows(catalog, airport, now, language);
        Check(rows.Length == 128, $"Incomplete sample schedule: {airport.Code}.");
        Check(rows.All(row => row.Destination.Length > 0), "Missing destination name.");
        Check(airport.LocalTime(now).Offset != TimeSpan.MinValue, "Invalid airport time zone.");
    }
}

Check(LaunchOptions.Parse(["/s"]).Mode == LaunchMode.ScreenSaver, "Full-screen mode.");
Check(LaunchOptions.Parse(["/c:42"]).Mode == LaunchMode.Settings, "Settings mode.");
Check(LaunchOptions.Parse(["/p", "123"]).PreviewParent == 123, "Separate preview handle.");
Check(LaunchOptions.Parse(["/P:123"]).PreviewParent == 123, "Inline preview handle.");
Reject(() => LaunchOptions.Parse(["/p", "0"]), "Reject an invalid preview parent.");

Check(catalog.City("TYO", "en") == "TOKYO", "Resolve sample city strings.");
Check(catalog.City("TYO", "ko") == "도쿄", "Translate sample city strings.");
var sampleGates = SampleSchedule
    .Rows(catalog, catalog.Get("ICN"), now, "en")
    .Select(row => row.Gate)
    .Distinct()
    .Count();
Check(sampleGates > 1, "Sample gates must vary between departures.");

var normalized = new BoardSettings
{
    Scale = 0,
    Density = -5,
    RefreshSeconds = 1,
}.Normalize();
Check(normalized.Scale == 0.5, "Reject an unusable display scale.");
Check(normalized.Density == 8, "Reject a negative row count.");
Check(normalized.RefreshSeconds == 60, "Enforce the minimum refresh interval.");

var operation = Fixtures.Flight("NH 1", "Operator", "HL123");
var alias = Fixtures.Flight("UA 2", "IsCodeshared", "");
var grouped = Codeshares.Group([operation, alias, operation]);
Check(grouped.Length == 1, "Codeshares occupy one row.");
Check(grouped[0].Variants.Length == 2, "Codeshares preserve both flight numbers.");
var other = Fixtures.Flight("JL 3", "Operator", "JA456");
Check(Codeshares.Group([operation, other, alias]).Length == 2, "Do not guess ambiguous aliases.");
var unknown = operation with { DestinationCode = "" };
Check(
    Codeshares.Group([unknown, other with { DestinationCode = "" }]).Length == 2,
    "Unknown destinations must not be grouped."
);

var parsed = AeroDataBoxClient.Parse("ICN", Fixtures.Response, now);
Check(parsed.Flights.Length == 1, "Parse and group provider codeshares.");
Check(parsed.Flights[0].Variants.Length == 2, "Parse marketing flight number.");
var english = FlightRows.Create(parsed, catalog, catalog.Get("ICN"), Fixtures.Time, "en");
var korean = FlightRows.Create(parsed, catalog, catalog.Get("ICN"), Fixtures.Time, "ko");
Check(english[0].Destination != korean[0].Destination, "Destination language should rotate.");
var rotated = FlightRows.Create(
    parsed,
    catalog,
    catalog.Get("ICN"),
    Fixtures.Time.AddSeconds(4),
    "en"
);
Check(english[0].Flight != rotated[0].Flight, "Codeshare number should rotate in one row.");
Check(
    FlightRows
        .Create(parsed with { FetchedAt = now.AddDays(-2) }, catalog, catalog.Get("ICN"), now, "en")
        .Length == 0,
    "Do not show a stale schedule."
);

var storage = Path.Combine(Path.GetTempPath(), "DepartureBoard.Tests-" + Guid.NewGuid());

try
{
    var settings = new SettingsRepository(storage);
    settings.Save(new BoardSettings { Airport = "HND", SampleData = false });
    Check(settings.Load().Airport == "HND", "Settings persist.");
    Check(
        !File.ReadAllText(Path.Combine(storage, "settings.json")).Contains("apiKey"),
        "Settings never contain an API key."
    );

    using var handler = new Fixtures.CountingHandler();
    using var http = new HttpClient(handler);
    var provider = new AeroDataBoxClient(http);
    var first = new FlightRepository(storage, provider);
    var second = new FlightRepository(storage, provider);
    await Task.WhenAll(
        first.RefreshAsync("ICN", "test-key", 300, default),
        second.RefreshAsync("ICN", "test-key", 300, default)
    );
    await second.RefreshAsync("ICN", "test-key", 300, default);
    Check(handler.Calls == 1, "One provider request across competing repositories.");
    Check(second.Read("ICN")?.Flights.Length == 1, "A second process reads the shared cache.");

    var prior = second.Read("ICN")!.FetchedAt;
    var changed = new FlightSnapshot("ICN", prior.AddSeconds(10), []);
    File.WriteAllText(
        Path.Combine(storage, "ICN.json"),
        System.Text.Json.JsonSerializer.Serialize(changed)
    );
    File.SetLastWriteTimeUtc(Path.Combine(storage, "ICN.json"), DateTime.UtcNow.AddSeconds(2));
    Check(second.Read("ICN")!.FetchedAt != prior, "Detect another process's cache update.");

    handler.Fail = true;
    await first.RefreshAsync("NRT", "test-key", 300, default);
    await second.RefreshAsync("NRT", "test-key", 300, default);
    Check(handler.Calls == 2, "Share API failure backoff across processes.");
    Check(second.LastError is not null, "Expose provider failure without crashing.");
}
finally
{
    Directory.Delete(storage, true);
}

Console.WriteLine($"Passed {assertions} assertions across 40 airports.");
