using System.Globalization;
using DepartureBoard.Core.Airports;

namespace DepartureBoard.Core.Flights;

public static class SampleSchedule
{
    public static BoardRow[] Rows(
        AirportCatalog catalog,
        AirportProfile airport,
        DateTimeOffset now,
        string language,
        int count = 128
    )
    {

        var routes = airport.Data.Child("routes").EnumerateArray().ToArray();
        var gates = airport.Data.Strings("gates");
        var firstSlot = now.ToUnixTimeSeconds() / 300 - 1;
        var rows = new List<BoardRow>();

        for (var index = 0; index < count; index++)
        {
            var slot = firstSlot + index;
            var routeIndex = (int)(slot % routes.Length);
            var route = routes[routeIndex];
            var seed = StableSeed(slot, routeIndex);
            var departure = DateTimeOffset.FromUnixTimeSeconds(slot * 300);
            var delay = seed % 23 == 0 ? 15 : 0;
            var minutes = Math.Ceiling((departure - now).TotalMinutes) + delay;
            var status = Status(seed, delay, minutes);
            var carrier = route.Text("carrier");
            var number =
                carrier
                + " "
                + route.Number("number").ToString("000", CultureInfo.InvariantCulture);
            rows.Add(
                new BoardRow(
                    airport.LocalTime(departure).ToString("HH:mm", CultureInfo.InvariantCulture),
                    delay == 0
                        ? ""
                        : airport
                            .LocalTime(departure.AddMinutes(delay))
                            .ToString("HH:mm", CultureInfo.InvariantCulture),
                    catalog.City(route.Text("city"), language),
                    number,
                    number,
                    catalog.Airline(carrier),
                    "",
                    gates[(int)(seed % gates.Length)],
                    "",
                    "",
                    status
                )
            );
        }

        return rows.ToArray();
    }

    private static uint StableSeed(long slot, int routeIndex)
    {

        // Mix adjacent slots to avoid repeating gates when route and gate counts share a factor.
        var mixed = unchecked((uint)slot * 2654435761U);
        return mixed ^ (mixed >> 16) ^ ((uint)routeIndex * 397U);
    }

    private static string Status(long seed, int delay, double minutes)
    {

        if (seed % 149 == 0)
        {
            return "cancelled";
        }

        if (delay > 0)
        {
            return "delayed";
        }

        if (minutes < 0)
        {
            return "departed";
        }

        if (minutes <= 8)
        {
            return "closing";
        }

        if (minutes <= 25)
        {
            return "boarding";
        }
        return minutes <= 45 ? "gate" : "scheduled";
    }
}
