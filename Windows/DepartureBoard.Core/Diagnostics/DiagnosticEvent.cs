namespace DepartureBoard.Core.Diagnostics;

// Deliberately excludes credentials, URLs, provider bodies and exception messages.
public sealed record DiagnosticEvent(
    string Name,
    string? Airport = null,
    string? State = null,
    int? Status = null,
    int? Count = null,
    double? ElapsedMs = null,
    int? RetrySeconds = null,
    double? CacheAgeSeconds = null
);

public interface IDiagnosticSink
{
    void Write(DiagnosticEvent entry);
}
