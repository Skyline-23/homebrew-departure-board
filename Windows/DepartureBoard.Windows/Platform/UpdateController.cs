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
    private SparkleUpdater? updater;
    private bool disposed;

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

    private async void RunCheck(bool requested)
    {

        try
        {
            if (disposed)
                return;
            var current = updater ??= CreateUpdater();

            if (requested)
                await current.CheckForUpdatesAtUserRequest();
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
            RelaunchAfterUpdate = true,
            CustomInstallerArguments =
                $"/SILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR=\"{Path.TrimEndingDirectorySeparator(AppContext.BaseDirectory)}\"",
        };
        current.CloseApplicationAsync += CloseApplication;
        return current;
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
