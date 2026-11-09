using System.Net;
using System.Text;
using DepartureBoard.Core.Flights;

internal static class Fixtures
{
    internal static readonly DateTimeOffset Time = DateTimeOffset.Parse(
        "2026-11-09T09:00:00Z",
        System.Globalization.CultureInfo.InvariantCulture
    );

    internal static readonly byte[] Response = Encoding.UTF8.GetBytes(
        """
        {
          "departures": [
            {
              "number": "NH 1", "codeshareStatus": "IsOperator", "status": "Boarding",
              "airline": { "name": "ANA", "icao": "ANA" },
              "aircraft": { "reg": "JA123" },
              "departure": { "scheduledTime": { "utc": "2026-11-09 09:10Z" }, "gate": "12" },
              "arrival": { "airport": { "iata": "NRT", "municipalityName": "Tokyo" } }
            },
            {
              "number": "UA 2", "codeshareStatus": "IsCodeshared", "status": "Boarding",
              "airline": { "name": "United Airlines", "icao": "UAL" },
              "departure": { "scheduledTime": { "utc": "2026-11-09 09:10Z" }, "gate": "12" },
              "arrival": { "airport": { "iata": "NRT", "municipalityName": "Tokyo" } }
            }
          ]
        }
        """
    );

    internal static Flight Flight(string number, string kind, string aircraft)
    {

        return new Flight(
            number,
            Time,
            null,
            "NRT",
            "Tokyo",
            "Boarding",
            "12",
            "",
            "",
            kind,
            aircraft,
            "",
            [new FlightVariant(number, number, "")]
        );
    }

    internal sealed class CountingHandler : HttpMessageHandler
    {
        private int calls;

        internal int Calls => calls;
        internal bool Fail { get; set; }

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken
        )
        {
            Interlocked.Increment(ref calls);
            await Task.Delay(30, cancellationToken);
            return new HttpResponseMessage(
                Fail ? HttpStatusCode.TooManyRequests : HttpStatusCode.OK
            )
            {
                Content = new ByteArrayContent(Response),
            };
        }
    }
}
