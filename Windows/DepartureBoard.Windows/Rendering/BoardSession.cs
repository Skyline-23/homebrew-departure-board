using System;
using DepartureBoard.Core.Airports;
using DepartureBoard.Core.Flights;
using DepartureBoard.Core.Settings;

namespace DepartureBoard.Windows.Rendering;

internal sealed class BoardSession(AirportCatalog catalog, FlightRepository flights)
{
    private string? lastFrameKey;
    private DateTimeOffset startedAt = DateTimeOffset.UtcNow;
    private string? airportCode;

    public BoardFrame? Frame { get; private set; }

    public bool Update(BoardSettings settings, DateTimeOffset now)
    {
        if (airportCode != settings.Airport)
        {
            startedAt = now;
            airportCode = settings.Airport;
        }

        var elapsed = (now - startedAt).TotalSeconds;
        var airport = catalog.Get(settings.Airport);
        var language = settings.Language switch
        {
            "english" => "en",
            "native" => airport.Language,
            _ => (int)(elapsed / 12) % 2 == 0 ? "en" : airport.Language,
        };
        var snapshot = flights.Read(airport.Code);
        var key =
            $"{settings}:{now.ToUnixTimeSeconds() / 4}:{(int)(elapsed / 15)}:{language}:{snapshot?.FetchedAt}";

        if (key == lastFrameKey)
        {
            return false;
        }

        var rows = settings.SampleData
            ? SampleSchedule.Rows(catalog, airport, now, language)
            : FlightRows.Create(snapshot, catalog, airport, now, language);
        Frame = new BoardFrame(airport, rows, now, language, settings, (int)(elapsed / 15));
        lastFrameKey = key;
        return true;
    }
}
