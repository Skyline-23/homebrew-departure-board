using System;
using DepartureBoard.Core.Airports;
using DepartureBoard.Core.Flights;
using DepartureBoard.Core.Settings;

namespace DepartureBoard.Windows.Rendering;

internal sealed class BoardSession(AirportCatalog catalog, FlightRepository flights)
{
    private readonly record struct RowKey(
        string Airport,
        bool SampleData,
        long DataTick,
        string Language,
        FlightSnapshot? Snapshot
    );

    private readonly record struct FrameKey(
        BoardSettings Settings,
        RowKey Rows,
        int Page,
        bool HasApiKey,
        string? Error
    );

    private FrameKey? lastFrameKey;
    private RowKey? lastRowKey;
    private DateTimeOffset startedAt = DateTimeOffset.UtcNow;
    private string? airportCode;

    public BoardFrame? Frame { get; private set; }

    public bool Update(BoardSettings settings, DateTimeOffset now, bool hasApiKey)
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
        // Sample rows and every clock change once per minute. Live codeshares still
        // rotate every four seconds, and shared-cache updates remain visible.
        var snapshot = settings.SampleData ? null : flights.Read(airport.Code);
        var rowsKey = new RowKey(
            airport.Code,
            settings.SampleData,
            now.ToUnixTimeSeconds() / (settings.SampleData ? 60 : 4),
            language,
            snapshot
        );
        var page = (int)(elapsed / 15);
        var key = new FrameKey(settings, rowsKey, page, hasApiKey, flights.LastError);

        if (key == lastFrameKey)
        {
            return false;
        }

        var rows =
            lastRowKey == rowsKey && Frame is not null ? Frame.Rows
            : settings.SampleData ? SampleSchedule.Rows(catalog, airport, now, language)
            : FlightRows.Create(snapshot, catalog, airport, now, language);
        Frame = new BoardFrame(
            airport,
            rows,
            now,
            language,
            settings,
            page,
            EmptyMessage(settings, snapshot, now, hasApiKey)
        );
        lastFrameKey = key;
        lastRowKey = rowsKey;
        return true;
    }

    private string EmptyMessage(
        BoardSettings settings,
        FlightSnapshot? snapshot,
        DateTimeOffset now,
        bool hasApiKey
    )
    {

        if (settings.SampleData)
        {
            return "data.noDepartures";
        }

        if (!hasApiKey)
        {
            return "data.configure";
        }

        if (snapshot is not null && now - snapshot.FetchedAt < TimeSpan.FromDays(1))
        {
            return "data.noDepartures";
        }

        return flights.LastError is null ? "data.loading" : "data.unavailable";
    }
}
