using System;
using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using DepartureBoard.Core.Airports;
using DepartureBoard.Core.Diagnostics;
using DepartureBoard.Core.Flights;
using DepartureBoard.Core.Settings;
using DepartureBoard.Windows.Platform;

namespace DepartureBoard.Windows;

internal sealed class AppServices : IDisposable
{
    private readonly HttpClient http = new() { Timeout = TimeSpan.FromSeconds(25) };
    private readonly CancellationTokenSource cancellation = new();
    private readonly CredentialStore credentials = new();
    private readonly SettingsRepository settingsRepository;
    private string apiKey;

    public AppServices(string? isolatedStorage = null)
    {

        var resources = Path.Combine(AppContext.BaseDirectory, "Resources");
        var storage =
            isolatedStorage
            ?? Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "DepartureBoard"
            );
        Diagnostics = new DiagnosticLog(
            Path.Combine(storage, "Logs"),
            typeof(AppServices).Assembly.GetName().Version?.ToString() ?? "development"
        );
        Catalog = new AirportCatalog(resources);
        settingsRepository = new SettingsRepository(storage);
        Settings = settingsRepository.Load();
        apiKey = isolatedStorage is null ? credentials.Read() : "";
        Flights = new FlightRepository(
            Path.Combine(storage, "Flights"),
            new AeroDataBoxClient(http),
            Diagnostics
        );
        Diagnostics.Write(
            new(
                "app.services_initialized",
                Settings.Airport,
                HasApiKey ? "credential_available" : "credential_missing"
            )
        );
    }

    public AirportCatalog Catalog { get; }
    public IDiagnosticSink Diagnostics { get; }
    public FlightRepository Flights { get; }
    public BoardSettings Settings { get; private set; }
    public bool HasApiKey => apiKey.Length > 0;
    public event EventHandler? SettingsChanged;
    public event EventHandler? DataChanged;

    public void Save(BoardSettings settings, string replacementKey)
    {

        settings = settings.Normalize();
        Catalog.Get(settings.Airport);
        credentials.Save(replacementKey);
        apiKey = credentials.Read();
        settingsRepository.Save(settings);
        StartupRegistration.Apply(settings.LaunchAtLogin);
        Settings = settings;
        Diagnostics.Write(
            new("settings.saved", settings.Airport, settings.SampleData ? "sample" : "live")
        );
        SettingsChanged?.Invoke(this, EventArgs.Empty);
        _ = RefreshAsync();
    }

    internal void UsePreviewSettings(BoardSettings settings)
    {

        Settings = settings;
    }

    public async Task RefreshAsync()
    {

        if (Settings.SampleData)
        {
            return;
        }

        try
        {
            await Flights
                .RefreshAsync(Settings.Airport, apiKey, Settings.RefreshSeconds, cancellation.Token)
                .ConfigureAwait(false);

            if (!cancellation.IsCancellationRequested)
            {
                _ = System.Windows.Application.Current.Dispatcher.BeginInvoke(() =>
                    DataChanged?.Invoke(this, EventArgs.Empty)
                );
            }
        }
        catch (OperationCanceledException) when (cancellation.IsCancellationRequested)
        {
            // Application shutdown cancels any in-flight request.
        }
    }

    public void Dispose()
    {

        cancellation.Cancel();
        Diagnostics.Write(new("app.services_stopped"));
        cancellation.Dispose();
        http.Dispose();
    }
}
