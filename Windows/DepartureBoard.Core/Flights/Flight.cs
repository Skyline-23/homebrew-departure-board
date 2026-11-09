namespace DepartureBoard.Core.Flights;

public sealed record FlightVariant(string Number, string Airline, string Icao);

public sealed record Flight(
    string Number,
    DateTimeOffset Scheduled,
    DateTimeOffset? Revised,
    string DestinationCode,
    string DestinationName,
    string Status,
    string Gate,
    string Terminal,
    string Counter,
    string CodeshareStatus,
    string Aircraft,
    string CallSign,
    FlightVariant[] Variants
);

public sealed record FlightSnapshot(string Airport, DateTimeOffset FetchedAt, Flight[] Flights);

public sealed record BoardRow(
    string Time,
    string Expected,
    string Destination,
    string Flight,
    string OperatorFlight,
    string Airline,
    string Icao,
    string Gate,
    string Terminal,
    string Counter,
    string Status
);
