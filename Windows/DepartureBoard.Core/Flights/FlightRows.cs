using System.Globalization;
using DepartureBoard.Core.Airports;

namespace DepartureBoard.Core.Flights;

public static class FlightRows
{
    public static BoardRow[] Create(
        FlightSnapshot? snapshot,
        AirportCatalog catalog,
        AirportProfile airport,
        DateTimeOffset now,
        string language
    )
    {

        if (snapshot is null || now - snapshot.FetchedAt > TimeSpan.FromDays(1))
        {
            return [];
        }

        return snapshot
            .Flights.Where(flight => flight.Scheduled >= now.AddMinutes(-30))
            .Where(flight => FitsTerminal(flight, airport))
            .Select(flight => Row(flight, catalog, airport, now, language))
            .ToArray();
    }

    private static bool FitsTerminal(Flight flight, AirportProfile airport)
    {

        var terminal = airport.Data.Text("terminal");
        return terminal.Length == 0 || flight.Terminal.Length == 0 || flight.Terminal == terminal;
    }

    private static BoardRow Row(
        Flight flight,
        AirportCatalog catalog,
        AirportProfile airport,
        DateTimeOffset now,
        string language
    )
    {

        var variant =
            flight.Variants.Length == 0
                ? new FlightVariant(flight.Number, "", "")
                : flight.Variants[(int)(now.ToUnixTimeSeconds() / 4 % flight.Variants.Length)];
        var changed =
            flight.Revised.HasValue
            && Math.Abs((flight.Revised.Value - flight.Scheduled).TotalMinutes) >= 1;
        var status = Status(flight.Status);

        if (status == "scheduled" && flight.Revised - flight.Scheduled >= TimeSpan.FromMinutes(15))
        {
            status = "delayed";
        }

        return new BoardRow(
            airport.LocalTime(flight.Scheduled).ToString("HH:mm", CultureInfo.InvariantCulture),
            changed
                ? airport
                    .LocalTime(flight.Revised!.Value)
                    .ToString("HH:mm", CultureInfo.InvariantCulture)
                : "",
            catalog.Destination(flight.DestinationCode, language, flight.DestinationName),
            variant.Number,
            flight.Number,
            variant.Airline,
            variant.Icao,
            flight.Gate,
            flight.Terminal,
            flight.Counter,
            status
        );
    }

    private static string Status(string status)
    {

        return status switch
        {
            "Expected" => "scheduled",
            "CheckIn" => "checkin",
            "Boarding" => "boarding",
            "GateClosed" => "closed",
            "Departed" or "EnRoute" => "departed",
            "Delayed" => "delayed",
            "Canceled" => "cancelled",
            "Diverted" => "diverted",
            _ => "unknown",
        };
    }
}
