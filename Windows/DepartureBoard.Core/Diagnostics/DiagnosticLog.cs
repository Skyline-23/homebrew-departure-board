using System.Text.Json;
using System.Text.Json.Serialization;

namespace DepartureBoard.Core.Diagnostics;

public sealed class DiagnosticLog(
    string directory,
    string version = "development",
    long maximumBytes = 1024 * 1024
) : IDiagnosticSink
{
    private sealed class SilentSink : IDiagnosticSink
    {
        public void Write(DiagnosticEvent entry) { }
    }

    private readonly object gate = new();
    private readonly Dictionary<string, DateTimeOffset> repeatedEvents = [];
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    public static IDiagnosticSink None { get; } = new SilentSink();
    public string FilePath => Path.Combine(directory, "departure-board.log");

    public void Write(DiagnosticEvent entry)
    {

        lock (gate)
        {
            if (ShouldSuppress(entry))
            {
                return;
            }

            try
            {
                Directory.CreateDirectory(directory);
                using var lease = TryLease();

                if (lease is null)
                {
                    return;
                }

                Rotate();
                var record = new
                {
                    Timestamp = DateTimeOffset.UtcNow,
                    ProcessId = Environment.ProcessId,
                    Version = version,
                    Entry = entry,
                };
                File.AppendAllText(FilePath, JsonSerializer.Serialize(record, Options) + "\n");
            }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException)
            {
                // Diagnostics must not interrupt flight updates or desktop rendering.
            }
        }
    }

    private bool ShouldSuppress(DiagnosticEvent entry)
    {

        if (entry.Name is not ("flight.refresh_skipped" or "flight.cache_read_failed"))
        {
            return false;
        }

        var key = $"{entry.Name}:{entry.Airport}:{entry.State}";
        var now = DateTimeOffset.UtcNow;

        if (
            repeatedEvents.TryGetValue(key, out var previous)
            && now - previous < TimeSpan.FromMinutes(5)
        )
        {
            return true;
        }

        if (repeatedEvents.Count >= 128)
        {
            repeatedEvents.Clear();
        }

        repeatedEvents[key] = now;
        return false;
    }

    private FileStream? TryLease()
    {

        try
        {
            return new FileStream(
                FilePath + ".lock",
                FileMode.OpenOrCreate,
                FileAccess.ReadWrite,
                FileShare.None
            );
        }
        catch (IOException)
        {
            return null;
        }
    }

    private void Rotate()
    {

        if (!File.Exists(FilePath) || new FileInfo(FilePath).Length < maximumBytes)
        {
            return;
        }

        var first = FilePath + ".1";

        if (File.Exists(first))
        {
            File.Move(first, FilePath + ".2", true);
        }

        File.Move(FilePath, first, true);
    }
}
