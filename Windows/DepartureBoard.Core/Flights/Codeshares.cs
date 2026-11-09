namespace DepartureBoard.Core.Flights;

public static class Codeshares
{
    public static Flight[] Group(IEnumerable<Flight> records)
    {

        var unique = records.DistinctBy(flight => (flight.Number, flight.Scheduled)).ToArray();
        var operators = new List<Flight>();
        var ordered = unique.OrderByDescending(flight => Quality(flight));

        foreach (var flight in ordered.Where(flight => flight.CodeshareStatus != "IsCodeshared"))
        {
            var index = operators.FindIndex(existing => Compatible(existing, flight, true));

            if (index < 0)
            {
                operators.Add(flight);
            }
            else
            {
                operators[index] = Merge(operators[index], flight);
            }
        }

        foreach (var alias in unique.Where(flight => flight.CodeshareStatus == "IsCodeshared"))
        {
            var matches = operators
                .Select((flight, index) => (flight, index))
                .Where(candidate => Compatible(candidate.flight, alias, false))
                .ToArray();

            if (matches.Length == 1)
            {
                var index = matches[0].index;
                operators[index] = Merge(operators[index], alias);
            }
        }

        return operators
            .OrderBy(flight => flight.Scheduled)
            .ThenBy(flight => flight.Number)
            .ToArray();
    }

    private static int Quality(Flight flight)
    {

        return (flight.Aircraft.Length > 0 ? 1 : 0) + (flight.CallSign.Length > 0 ? 1 : 0);
    }

    private static bool Compatible(Flight first, Flight second, bool requireEvidence)
    {

        if (
            first.DestinationCode.Length == 0
            || first.Scheduled != second.Scheduled
            || first.DestinationCode != second.DestinationCode
        )
        {
            return false;
        }

        if (first.Gate.Length > 0 && second.Gate.Length > 0 && first.Gate != second.Gate)
        {
            return false;
        }

        var sameAircraft = first.Aircraft.Length > 0 && first.Aircraft == second.Aircraft;
        var sameCallSign = first.CallSign.Length > 0 && first.CallSign == second.CallSign;
        return !requireEvidence || sameAircraft || sameCallSign;
    }

    private static Flight Merge(Flight primary, Flight alias)
    {

        return primary with
        {
            Variants = primary
                .Variants.Concat(alias.Variants)
                .DistinctBy(variant => variant.Number)
                .ToArray(),
        };
    }
}
