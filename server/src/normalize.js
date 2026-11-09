// Keep provider-specific field names out of the native app.
export function normalizeDepartures(payload, airport, fetchedAt = new Date().toISOString()) {
  const departures = Array.isArray(payload.departures) ? payload.departures : [];
  const flights = departures.flatMap((flight) => {
    const departure = flight.departure ?? flight.movement;
    const destination = flight.arrival?.airport ?? flight.movement?.airport;
    const scheduled = departure?.scheduledTime;
    if (!scheduled?.utc || !Number.isFinite(Date.parse(scheduled.utc)) || !flight.number) return [];
    return [{
      number: flight.number,
      destinationCode: destination?.iata ?? "",
      destinationName: destination?.municipalityName ?? destination?.shortName ?? destination?.name ?? "",
      scheduledUtc: scheduled.utc,
      scheduledLocal: scheduled.local,
      revisedUtc: departure.revisedTime?.utc ?? null,
      status: flight.status ?? "Unknown",
      gate: departure.gate ?? "",
      terminal: departure.terminal ?? "",
      checkIn: departure.checkInDesk ?? "",
      airlineName: flight.airline?.name ?? "",
      airlineIata: flight.airline?.iata ?? "",
    }];
  });
  const unique = new Map(flights.map((flight) => [`${flight.number}/${flight.scheduledUtc}`, flight]));
  return {
    airport,
    source: "AeroDataBox",
    fetchedAt,
    stale: false,
    flights: [...unique.values()].sort((a, b) => Date.parse(a.scheduledUtc) - Date.parse(b.scheduledUtc)),
  };
}
