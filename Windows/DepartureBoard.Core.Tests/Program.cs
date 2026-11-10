using DepartureBoard.Core.Airports;
using DepartureBoard.Core.Diagnostics;
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

foreach (var language in new[] { "en", "ja", "ko" })
{
    Check(
        catalog.Strings.ValueOrPlaceholder("", language) == "—"
            && catalog.Strings.ValueOrPlaceholder(" \t", language) == "—",
        "Missing gate and counter values should remain visibly unavailable."
    );
    Check(
        catalog.Strings.ValueOrPlaceholder("A12", language) == "A12",
        "Preserve an assigned gate or counter value."
    );
    Check(
        catalog.Strings.Get("status.unknown", language).Length > 0
            && catalog.Strings.Get("status.scheduled", language).Length > 0,
        "Known and unavailable flight statuses must have visible labels."
    );
}

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
Check(
    new BoardSettings { Brightness = -1 }
        .Normalize()
        .Brightness == 0.35,
    "Match the macOS brightness range."
);
Check(
    new BoardSettings { Brightness = double.NaN }
        .Normalize()
        .Brightness == 1,
    "Reject non-finite brightness."
);
Check(
    new BoardSettings { RefreshSeconds = 21600, Style = "lcd" }
        .Normalize()
        .RefreshSeconds == 21600,
    "Keep the six-hour refresh option."
);
Check(
    new BoardSettings { Style = "lcd" }
        .Normalize()
        .Style == "lcd",
    "Keep the LCD option."
);

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

foreach (
    var (value, expected) in new[]
    {
        ("I,I", "I"),
        (" H ,H, H ,h ", "H"),
        ("J, K,J", "J, K"),
        ("11-14,11-14,16A", "11-14, 16A"),
        ("", ""),
        (", ,A,,", "A"),
    }
)
{
    var flight = operation with { Gate = value, Counter = value };
    var snapshot = new FlightSnapshot("HND", Fixtures.Time, [flight]);
    var row = FlightRows.Create(snapshot, catalog, catalog.Get("HND"), Fixtures.Time, "en")[0];
    Check(
        row.Gate == expected && row.Counter == expected,
        "Show each gate or check-in label once, keeping distinct labels and ranges."
    );
}

try
{
    var settings = new SettingsRepository(storage);
    settings.Save(
        new BoardSettings
        {
            Airport = "HND",
            SampleData = false,
            Brightness = 0.5,
            ReduceMotion = true,
            ShowAllDesktops = false,
        }
    );
    Check(settings.Load().Airport == "HND", "Settings persist.");
    Check(
        settings.Load().Brightness == 0.5
            && settings.Load().ReduceMotion
            && !settings.Load().ShowAllDesktops,
        "Display preferences persist."
    );
    Check(
        !File.ReadAllText(Path.Combine(storage, "settings.json")).Contains("apiKey"),
        "Settings never contain an API key."
    );

    using var handler = new Fixtures.CountingHandler();
    using var http = new HttpClient(handler);
    var provider = new AeroDataBoxClient(http);
    var diagnostics = new DiagnosticLog(Path.Combine(storage, "Logs"), "test");
    var first = new FlightRepository(storage, provider, diagnostics);
    var second = new FlightRepository(storage, provider, diagnostics);
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

    handler.Fault = new InvalidOperationException("private-error-message-sentinel");
    var failing = new FlightRepository(Path.Combine(storage, "fault"), provider, diagnostics);
    await failing.RefreshAsync("CDG", "test-key", 300, default);
    Check(failing.LastError is not null, "A failed background request must leave loading state.");

    var logText = File.ReadAllText(diagnostics.FilePath);
    Check(
        logText.Contains("flight.request_started") && logText.Contains("flight.request_finished"),
        "Record the request lifecycle."
    );
    Check(
        logText.Contains("flight.request_failed") && logText.Contains("429"),
        "Record provider status without the response body."
    );
    Check(
        !logText.Contains("test-key")
            && !logText.Contains("scheduledTime")
            && !logText.Contains("https://")
            && !logText.Contains("private-error-message-sentinel"),
        "Keep credentials, provider bodies and URLs out of logs."
    );

    // Provider failures must not multiply when users switch airports or restart the app.

    foreach (
        var status in new[]
        {
            System.Net.HttpStatusCode.TooManyRequests,
            System.Net.HttpStatusCode.Forbidden,
            System.Net.HttpStatusCode.ServiceUnavailable,
        }
    )
    {
        var retryStorage = Path.Combine(storage, status.ToString());
        using var retryHandler = new Fixtures.CountingHandler
        {
            Fail = true,
            FailureStatus = status,
            RetryAfter = new(TimeSpan.FromHours(2)),
        };
        using var retryHttp = new HttpClient(retryHandler);
        var retryProvider = new AeroDataBoxClient(retryHttp);

        foreach (var airport in catalog.Airports)
        {
            await new FlightRepository(retryStorage, retryProvider).RefreshAsync(
                airport.Code,
                "test-key",
                300,
                default
            );
        }
        Check(retryHandler.Calls == 1, $"One request, not 40, after account-wide HTTP {status}.");
        var state = System.Text.Json.JsonDocument.Parse(
            File.ReadAllText(Path.Combine(retryStorage, "provider.retry"))
        );
        Check(
            state.RootElement.GetProperty("After").GetDateTimeOffset()
                > DateTimeOffset.UtcNow.AddMinutes(119),
            "Respect the provider Retry-After delay."
        );
        Check(
            !File.ReadAllText(Path.Combine(retryStorage, "provider.retry")).Contains("test-key"),
            "Retry state must not contain the credential."
        );
        retryHandler.Fail = false;
        var rotatedKeyRepository = new FlightRepository(retryStorage, retryProvider);
        await rotatedKeyRepository.RefreshAsync("ICN", "replacement-key", 300, default);
        await new FlightRepository(retryStorage, retryProvider).RefreshAsync(
            "ICN",
            "replacement-key",
            300,
            default
        );
        Check(
            retryHandler.Calls == 2 && rotatedKeyRepository.Read("ICN") is not null,
            "A replacement key recovers immediately and shares its cache."
        );
        Console.WriteLine(
            $"Request fixture HTTP {(int)status}: 40 airport refreshes -> 1 HTTP request; key replacement -> 1 request."
        );
    }
    var retryDate = DateTimeOffset.UtcNow.AddHours(3);
    using (
        var dateHandler = new Fixtures.CountingHandler { Fail = true, RetryAfter = new(retryDate) }
    )
    using (var dateHttp = new HttpClient(dateHandler))
    {
        var dateStorage = Path.Combine(storage, "retry-date");
        await new FlightRepository(dateStorage, new AeroDataBoxClient(dateHttp)).RefreshAsync(
            "ICN",
            "test-key",
            300,
            default
        );
        var state = System.Text.Json.JsonDocument.Parse(
            File.ReadAllText(Path.Combine(dateStorage, "provider.retry"))
        );
        Check(
            Math.Abs(
                (
                    state.RootElement.GetProperty("After").GetDateTimeOffset() - retryDate
                ).TotalSeconds
            ) < 2,
            "Respect an HTTP-date Retry-After value."
        );
    }
    Check(
        new BoardSettings().RefreshSeconds == 300,
        "Use a five-minute default without changing a saved interval."
    );

    var rotating = new DiagnosticLog(Path.Combine(storage, "Rotation"), "test", 512);

    for (var index = 0; index < 50; index++)
    {
        rotating.Write(new("test.rotation", "ICN", Count: index));
    }

    var files = Directory
        .GetFiles(Path.Combine(storage, "Rotation"), "departure-board.log*")
        .Where(path => !path.EndsWith(".lock", StringComparison.Ordinal))
        .ToArray();
    Check(
        files.Length == 3 && files.All(path => new FileInfo(path).Length < 1024),
        "Bound diagnostic storage with two rotated files."
    );

    var denied = Path.Combine(storage, "NotADirectory");
    File.WriteAllText(denied, "occupied");
    new DiagnosticLog(denied).Write(new("test.unwritable"));
    Check(File.ReadAllText(denied) == "occupied", "A logging failure must not affect the app.");

    var repeated = new DiagnosticLog(Path.Combine(storage, "Repeated"));

    for (var index = 0; index < 60; index++)
    {
        repeated.Write(new("flight.refresh_skipped", "HND", "fresh_cache"));
        repeated.Write(new("flight.cache_read_failed", "HND"));
    }

    repeated.Write(new("flight.refresh_skipped", "ICN", "fresh_cache"));
    Check(
        File.ReadAllLines(repeated.FilePath).Length == 3,
        "Throttle repeated cache checks while keeping distinct airports and failures."
    );
}
finally
{
    Directory.Delete(storage, true);
}

Console.WriteLine($"Passed {assertions} assertions across 40 airports.");
