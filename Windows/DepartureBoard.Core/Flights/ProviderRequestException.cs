using System.Net;

namespace DepartureBoard.Core.Flights;

public sealed class ProviderRequestException(HttpStatusCode status, TimeSpan? retryAfter)
    : HttpRequestException($"AeroDataBox returned HTTP {(int)status}.", null, status)
{
    public TimeSpan? RetryAfter { get; } = retryAfter;
}
