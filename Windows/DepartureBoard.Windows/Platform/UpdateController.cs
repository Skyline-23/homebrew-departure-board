using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows;
using DepartureBoard.Core.Diagnostics;
using NetSparkleUpdater;
using NetSparkleUpdater.Enums;
using NetSparkleUpdater.SignatureVerifiers;

namespace DepartureBoard.Windows.Platform;

internal sealed class UpdateController : IDisposable
{
    private readonly IDiagnosticSink diagnostics;
    private readonly UpdateConfiguration configuration = new();
    private SparkleUpdater? updater;
    private bool disposed;
    private AppCastItem? pendingUpdate;
    private string? pendingPath;

    public bool AutomaticChecks => configuration.CheckForUpdate;
    public bool AutomaticUpdates => configuration.AutomaticUpdates;
    public DateTime? LastChecked =>
        configuration.LastCheckTime == DateTime.MinValue ? null : configuration.LastCheckTime;
    public bool IsChecking { get; private set; }
    public string Status { get; private set; } = "";
    public event EventHandler? Changed;

    public UpdateController(IDiagnosticSink diagnostics)
    {

        this.diagnostics = diagnostics;
    }

    public void Start()
    {

        RunCheck(false);
    }

    public void CheckForUpdates()
    {

        RunCheck(true);
    }

    public void SetOptions(bool checks, bool automaticUpdates)
    {

        try
        {
            configuration.SaveOptions(checks, automaticUpdates);

            if (updater is not null)
                updater.UserInteractionMode = automaticUpdates
                    ? UserInteractionMode.DownloadNoInstall
                    : UserInteractionMode.NotSilent;
        }
        catch (Exception error)
        {
            diagnostics.Write(new("update.preferences_failed", State: error.GetType().Name));
            Status = "Couldn't save update settings. Try again.";
        }
        NotifyChanged();
    }

    public async void Quit()
    {

        try
        {
            if (
                AutomaticUpdates
                && updater is not null
                && pendingUpdate is not null
                && pendingPath is not null
            )
            {
                updater.RelaunchAfterUpdate = false;
                await updater.InstallUpdate(pendingUpdate, pendingPath);
                return;
            }
        }
        catch (Exception error)
        {
            diagnostics.Write(new("update.install_failed", State: error.GetType().Name));
            Status = "Couldn't install the update. Try Check for updates again.";
            NotifyChanged();
            return;
        }
        Application.Current.Shutdown();
    }

    private async void RunCheck(bool requested)
    {

        try
        {
            if (disposed)
                return;

            if (requested && IsChecking)
                return;
            var current = updater ??= CreateUpdater();

            if (requested)
            {
                current.RelaunchAfterUpdate = true;
                await current.CheckForUpdatesAtUserRequest(ignoreSkippedVersions: true);
            }
            else
                await current.StartLoop(true, false, TimeSpan.FromDays(1));
        }
        catch (Exception error)
        {
            diagnostics.Write(new("update.check_failed", State: error.GetType().Name));

            if (requested && !disposed)
                MessageBox.Show(
                    "Couldn't check for updates. Check your connection and try again.",
                    "Departure Board",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information
                );
        }
    }

    private SparkleUpdater CreateUpdater()
    {

        var architecture =
            RuntimeInformation.OSArchitecture == Architecture.Arm64 ? "arm64" : "x64";
        var key = File.ReadAllText(
                Path.Combine(AppContext.BaseDirectory, "Resources", "Updates", "public-key.txt")
            )
            .Trim();

        if (Convert.FromBase64String(key).Length != 32)
            throw new InvalidDataException("Invalid update verification key.");
        var current = new SparkleUpdater(
            $"https://github.com/Skyline-23/homebrew-departure-board/releases/latest/download/appcast-windows-{architecture}.xml",
            new Ed25519Checker(SecurityMode.Strict, key)
        )
        {
            UIFactory = new NetSparkleUpdater.UI.WPF.UIFactory(),
            Configuration = configuration,
            UserInteractionMode = AutomaticUpdates
                ? UserInteractionMode.DownloadNoInstall
                : UserInteractionMode.NotSilent,
            RelaunchAfterUpdate = true,
            CustomInstallerArguments =
                $"/SILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR=\"{Path.TrimEndingDirectorySeparator(AppContext.BaseDirectory)}\"",
        };
        current.UpdateCheckStarted += _ =>
        {
            IsChecking = true;
            Status = "Checking for updates…";
            NotifyChanged();
        };
        current.UpdateCheckFinished += (_, status) =>
        {
            IsChecking = false;
            Status =
                status == UpdateStatus.UpdateAvailable ? "A new version is available."
                : status == UpdateStatus.UpdateNotAvailable ? "You're up to date."
                : "Couldn't check for updates. Try again.";
            NotifyChanged();
        };
        current.DownloadFinished += (item, path) =>
        {
            if (!AutomaticUpdates)
                return;
            pendingUpdate = item;
            pendingPath = path;
            Status = "Update downloaded. It will be installed when you quit.";
            NotifyChanged();
        };
        current.DownloadStarted += (_, _) =>
        {
            Status = "Downloading update…";
            NotifyChanged();
        };
        current.DownloadHadError += (_, _, _) =>
        {
            Status = "Couldn't download the update. Check for updates to retry.";
            NotifyChanged();
        };
        current.DownloadCanceled += (_, _) =>
        {
            Status = "Update download canceled.";
            NotifyChanged();
        };
        current.CloseApplicationAsync += CloseApplication;
        return current;
    }

    private void NotifyChanged()
    {

        if (!disposed)
            Application.Current.Dispatcher.BeginInvoke(() =>
                Changed?.Invoke(this, EventArgs.Empty)
            );
    }

    private static async Task CloseApplication()
    {

        await Application.Current.Dispatcher.InvokeAsync(() => Application.Current.Shutdown());
    }

    public void Dispose()
    {

        disposed = true;
        updater?.Dispose();
    }
}
