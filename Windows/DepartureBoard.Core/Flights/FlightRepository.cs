using System.Diagnostics;
using System.Text.Json;
using DepartureBoard.Core.Diagnostics;

namespace DepartureBoard.Core.Flights;

public sealed class FlightRepository(
    string directory,
    AeroDataBoxClient provider,
    IDiagnosticSink? sink = null
)
{
    private readonly IDiagnosticSink diagnostics = sink ?? DiagnosticLog.None;

    private sealed record CachedFile(DateTime ModifiedAt, FlightSnapshot Snapshot);

    private sealed record RetryState(DateTimeOffset After, string Message);

    private readonly SemaphoreSlim gate = new(1, 1);
    private readonly Dictionary<string, CachedFile> memory = [];

    public string? LastError { get; private set; }

    public FlightSnapshot? Read(string airport)
    {
        var path = SnapshotPath(airport);

        try
        {
            var modifiedAt = File.GetLastWriteTimeUtc(path);

            lock (memory)
            {
                if (memory.TryGetValue(airport, out var cached) && cached.ModifiedAt == modifiedAt)
                {
                    return cached.Snapshot;
                }
            }

            var snapshot = ReadJson<FlightSnapshot>(path);

            if (snapshot is null || snapshot.Airport != airport)
            {
                return null;
            }

            lock (memory)
            {
                memory[airport] = new CachedFile(modifiedAt, snapshot);
            }

            diagnostics.Write(
                new(
                    "flight.cache_loaded",
                    airport,
                    Count: snapshot.Flights.Length,
                    CacheAgeSeconds: Math.Max(
                        0,
                        (DateTimeOffset.UtcNow - snapshot.FetchedAt).TotalSeconds
                    )
                )
            );

            return snapshot;
        }
        catch (IOException)
        {
            diagnostics.Write(new("flight.cache_read_failed", airport));
            return null;
        }
    }

    public async Task RefreshAsync(
        string airport,
        string apiKey,
        int intervalSeconds,
        CancellationToken cancellationToken
    )
    {

        if (apiKey.Length == 0)
        {
            diagnostics.Write(new("flight.refresh_skipped", airport, "credential_unavailable"));
            return;
        }

        if (!await gate.WaitAsync(0, cancellationToken).ConfigureAwait(false))
        {
            diagnostics.Write(new("flight.refresh_skipped", airport, "refresh_in_progress"));
            return;
        }

        try
        {
            await RefreshLockedAsync(airport, apiKey, intervalSeconds, cancellationToken)
                .ConfigureAwait(false);
        }
        catch (IOException)
        {
            LastError = "The flight cache could not be updated.";
            diagnostics.Write(new("flight.request_failed", airport, "cache_write_failed"));
        }
        catch (UnauthorizedAccessException)
        {
            LastError = "The flight cache is not writable.";
            diagnostics.Write(new("flight.request_failed", airport, "cache_permission_denied"));
        }
        catch (Exception error)
            when (error is ArgumentException or InvalidOperationException or FormatException)
        {
            LastError = "The flight request could not be processed. See the diagnostic log.";
            diagnostics.Write(new("flight.request_failed", airport, error.GetType().Name));
        }
        finally
        {
            gate.Release();
        }
    }

    private async Task RefreshLockedAsync(
        string airport,
        string apiKey,
        int intervalSeconds,
        CancellationToken cancellationToken
    )
    {

        var path = SnapshotPath(airport);
        Directory.CreateDirectory(directory);
        using var lease = TryAcquireLease(path + ".lock");

        if (lease is null)
        {
            diagnostics.Write(new("flight.refresh_skipped", airport, "other_process_refresh"));
            return;
        }

        // Recheck after acquiring the cross-process lease. A screen saver or another
        // display may already have fetched this airport while we were waiting.
        var now = DateTimeOffset.UtcNow;
        var cached = Read(airport);
        var interval = TimeSpan.FromSeconds(Math.Max(60, intervalSeconds));

        if (cached is not null && now - cached.FetchedAt < interval)
        {
            diagnostics.Write(new("flight.refresh_skipped", airport, "fresh_cache"));
            return;
        }

        var retry = ReadJson<RetryState>(path + ".retry");

        if (retry is not null && now < retry.After)
        {
            LastError = retry.Message;
            diagnostics.Write(
                new(
                    "flight.refresh_skipped",
                    airport,
                    "backoff",
                    RetrySeconds: (int)Math.Ceiling((retry.After - now).TotalSeconds)
                )
            );
            return;
        }

        await FetchAsync(airport, apiKey, path, cancellationToken).ConfigureAwait(false);
    }

    private async Task FetchAsync(
        string airport,
        string apiKey,
        string path,
        CancellationToken cancellationToken
    )
    {

        var elapsed = Stopwatch.StartNew();
        diagnostics.Write(new("flight.request_started", airport));

        try
        {
            var snapshot = await provider
                .FetchAsync(airport, apiKey, cancellationToken)
                .ConfigureAwait(false);
            await WriteJsonAsync(path, snapshot, cancellationToken).ConfigureAwait(false);
            File.Delete(path + ".retry");
            LastError = null;
            diagnostics.Write(
                new(
                    "flight.request_finished",
                    airport,
                    "saved",
                    Count: snapshot.Flights.Length,
                    ElapsedMs: elapsed.Elapsed.TotalMilliseconds
                )
            );
        }
        catch (HttpRequestException error)
        {
            diagnostics.Write(
                new(
                    "flight.request_failed",
                    airport,
                    "http_error",
                    Status: error.StatusCode is { } code ? (int)code : null,
                    ElapsedMs: elapsed.Elapsed.TotalMilliseconds
                )
            );
            await DeferAsync(
                    airport,
                    path,
                    error.Message,
                    TimeSpan.FromMinutes(15),
                    cancellationToken
                )
                .ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            diagnostics.Write(
                new(
                    "flight.request_failed",
                    airport,
                    "timeout",
                    ElapsedMs: elapsed.Elapsed.TotalMilliseconds
                )
            );
            await DeferAsync(
                    airport,
                    path,
                    "The flight request timed out.",
                    TimeSpan.FromMinutes(2),
                    cancellationToken
                )
                .ConfigureAwait(false);
        }
        catch (Exception error) when (error is JsonException or InvalidDataException)
        {
            diagnostics.Write(
                new(
                    "flight.request_failed",
                    airport,
                    "invalid_response",
                    ElapsedMs: elapsed.Elapsed.TotalMilliseconds
                )
            );
            await DeferAsync(
                    airport,
                    path,
                    "The flight provider returned an invalid response.",
                    TimeSpan.FromMinutes(15),
                    cancellationToken
                )
                .ConfigureAwait(false);
        }
    }

    private async Task DeferAsync(
        string airport,
        string path,
        string message,
        TimeSpan delay,
        CancellationToken cancellationToken
    )
    {

        LastError = message;
        diagnostics.Write(
            new(
                "flight.retry_scheduled",
                airport,
                State: "backoff",
                RetrySeconds: (int)delay.TotalSeconds
            )
        );
        var retry = new RetryState(DateTimeOffset.UtcNow + delay, message);
        await WriteJsonAsync(path + ".retry", retry, cancellationToken).ConfigureAwait(false);
    }

    private static FileStream? TryAcquireLease(string path)
    {

        try
        {
            return new FileStream(
                path,
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

    private static T? ReadJson<T>(string path)
    {
        try
        {
            return JsonSerializer.Deserialize<T>(File.ReadAllText(path));
        }
        catch (Exception error) when (error is IOException or JsonException)
        {
            return default;
        }
    }

    private static async Task WriteJsonAsync<T>(
        string path,
        T value,
        CancellationToken cancellationToken
    )
    {
        var temporaryPath = path + ".new";
        await File.WriteAllTextAsync(
                temporaryPath,
                JsonSerializer.Serialize(value),
                cancellationToken
            )
            .ConfigureAwait(false);
        File.Move(temporaryPath, path, true);
    }

    private string SnapshotPath(string airport)
    {

        if (airport.Length != 3 || !airport.All(char.IsAsciiLetterUpper))
        {
            throw new ArgumentException("Invalid airport code.", nameof(airport));
        }

        return Path.Combine(directory, airport + ".json");
    }
}
