using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
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

    private sealed record RetryState(
        DateTimeOffset After,
        string Message,
        string? CredentialHash = null,
        int Attempts = 1
    );

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
        using var providerLease = TryAcquireLease(Path.Combine(directory, "provider.lock"));

        if (providerLease is null)
        {
            diagnostics.Write(new("flight.refresh_skipped", airport, "other_process_refresh"));
            return;
        }
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

        var credentialHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(apiKey)));
        var accountRetry = ReadJson<RetryState>(Path.Combine(directory, "provider.retry"));
        var airportRetry = ReadJson<RetryState>(path + ".retry");
        var retry = new[] { accountRetry, airportRetry }
            .Where(item =>
                item is not null && item.CredentialHash == credentialHash && item.After > now
            )
            .OrderByDescending(item => item!.After)
            .FirstOrDefault();

        if (retry is not null)
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

        await FetchAsync(airport, apiKey, credentialHash, path, cancellationToken)
            .ConfigureAwait(false);
    }

    private async Task FetchAsync(
        string airport,
        string apiKey,
        string credentialHash,
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
            File.Delete(Path.Combine(directory, "provider.retry"));
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
                    error is ProviderRequestException providerError
                        ? providerError.RetryAfter
                        : null,
                    credentialHash,
                    error.StatusCode is { } status ? (int)status : 0,
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
                    null,
                    credentialHash,
                    0,
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
                    credentialHash,
                    200,
                    cancellationToken
                )
                .ConfigureAwait(false);
        }
    }

    private async Task DeferAsync(
        string airport,
        string path,
        string message,
        TimeSpan? requestedDelay,
        string credentialHash,
        int status,
        CancellationToken cancellationToken
    )
    {

        LastError = message;
        var accountWide = status is 0 or 401 or 403 or 429 || status >= 500;
        var retryPath = accountWide ? Path.Combine(directory, "provider.retry") : path + ".retry";
        var previous = ReadJson<RetryState>(retryPath);
        var attempts =
            previous?.CredentialHash == credentialHash ? Math.Min(8, previous.Attempts + 1) : 1;
        var delay = requestedDelay is { TotalSeconds: > 0 } explicitDelay
            ? explicitDelay
            : TimeSpan.FromSeconds(
                status is 401 or 403 or 429 ? 3600
                : status >= 500 ? Math.Min(3600, 900 * Math.Pow(2, attempts - 1))
                : Math.Min(900, 60 * Math.Pow(2, attempts - 1))
            );

        if (delay < TimeSpan.FromSeconds(60))
            delay = TimeSpan.FromSeconds(60);
        diagnostics.Write(
            new(
                "flight.retry_scheduled",
                airport,
                State: "backoff",
                RetrySeconds: (int)delay.TotalSeconds
            )
        );
        var retry = new RetryState(
            DateTimeOffset.UtcNow + delay,
            message,
            credentialHash,
            attempts
        );
        await WriteJsonAsync(retryPath, retry, cancellationToken).ConfigureAwait(false);
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
