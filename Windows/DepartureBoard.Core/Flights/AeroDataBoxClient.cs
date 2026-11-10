using System.Globalization;
using System.Text.Json;
using DepartureBoard.Core.Airports;

namespace DepartureBoard.Core.Flights;

public sealed class AeroDataBoxClient(HttpClient client)
{
    private const string Host = "aerodatabox.p.rapidapi.com";

    public async Task<FlightSnapshot> FetchAsync(
        string airport,
        string apiKey,
        CancellationToken cancellationToken
    )
    {

        if (airport.Length != 3 || !airport.All(char.IsAsciiLetterUpper))
        {
            throw new ArgumentException("An airport IATA code is required.", nameof(airport));
        }

        var path =
            $"https://{Host}/flights/airports/iata/{airport}"
            + "?offsetMinutes=-30&durationMinutes=720&direction=Departure&withLeg=true"
            + "&withCancelled=true&withCodeshared=true&withCargo=false&withPrivate=false&withLocation=false";
        using var request = new HttpRequestMessage(HttpMethod.Get, path);
        request.Headers.Add("X-RapidAPI-Key", apiKey);
        request.Headers.Add("X-RapidAPI-Host", Host);
        using var response = await client
            .SendAsync(request, cancellationToken)
            .ConfigureAwait(false);

        if (!response.IsSuccessStatusCode)
        {
            var retryAfter = response.Headers.RetryAfter;
            var delay =
                retryAfter?.Delta
                ?? (retryAfter?.Date is { } date ? date - DateTimeOffset.UtcNow : (TimeSpan?)null);
            throw new ProviderRequestException(response.StatusCode, delay);
        }
        var bytes = await response
            .Content.ReadAsByteArrayAsync(cancellationToken)
            .ConfigureAwait(false);
        return Parse(airport, bytes, DateTimeOffset.UtcNow);
    }

    public static FlightSnapshot Parse(string airport, byte[] bytes, DateTimeOffset fetchedAt)
    {

        using var document = JsonDocument.Parse(bytes);
        var flights = new List<Flight>();
        var departures = document.RootElement.Child("departures");

        if (departures.ValueKind != JsonValueKind.Array)
        {
            throw new InvalidDataException("AeroDataBox did not return a departures array.");
        }

        foreach (var flight in departures.EnumerateArray())
        {
            var movement = flight.Child("departure");

            if (movement.ValueKind != JsonValueKind.Object)
            {
                movement = flight.Child("movement");
            }

            if (!TryDate(movement.Child("scheduledTime").Text("utc"), out var scheduled))
            {
                continue;
            }

            var destination = flight.Child("arrival").Child("airport");

            if (destination.ValueKind != JsonValueKind.Object)
            {
                destination = flight.Child("movement").Child("airport");
            }

            var number = flight.Text("number");
            var airline = flight.Child("airline");
            DateTimeOffset? revised = TryDate(
                movement.Child("revisedTime").Text("utc"),
                out var value
            )
                ? value
                : null;
            flights.Add(
                new Flight(
                    number,
                    scheduled,
                    revised,
                    destination.Text("iata"),
                    destination.Text("municipalityName", destination.Text("name")),
                    flight.Text("status", "Unknown"),
                    movement.Text("gate"),
                    movement.Text("terminal"),
                    movement.Text("checkInDesk"),
                    flight.Text("codeshareStatus"),
                    flight.Child("aircraft").Text("reg"),
                    flight.Text("callSign"),
                    [new FlightVariant(number, airline.Text("name"), airline.Text("icao"))]
                )
            );
        }

        return new FlightSnapshot(airport, fetchedAt, Codeshares.Group(flights));
    }

    private static bool TryDate(string value, out DateTimeOffset date)
    {

        return DateTimeOffset.TryParse(
            value,
            CultureInfo.InvariantCulture,
            DateTimeStyles.AssumeUniversal,
            out date
        );
    }
}
