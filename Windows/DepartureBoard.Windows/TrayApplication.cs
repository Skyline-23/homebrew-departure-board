using System;
using System.Drawing;
using System.IO;
using System.Threading;
using System.Windows;
using System.Windows.Threading;
using DepartureBoard.Windows.Platform;
using DepartureBoard.Windows.Views;
using Forms = System.Windows.Forms;

namespace DepartureBoard.Windows;

internal sealed class TrayApplication : IDisposable
{
    private readonly AppServices services;
    private readonly DisplayWindows displays;
    private readonly Forms.NotifyIcon tray;
    private readonly Forms.ContextMenuStrip menu;
    private readonly Icon? icon;
    private readonly EventWaitHandle showSettingsSignal = new(
        false,
        EventResetMode.AutoReset,
        "Local\\DepartureBoard.ShowSettings"
    );
    private readonly RegisteredWaitHandle waiting;
    private readonly DispatcherTimer refreshTimer;
    private SettingsWindow? settingsWindow;
    private BoardWindow? preview;

    public TrayApplication(AppServices services)
    {

        this.services = services;
        displays = new DisplayWindows(services);
        menu = new Forms.ContextMenuStrip();
        menu.Items.Add("Settings", null, (_, _) => ShowSettings());
        menu.Items.Add("Preview", null, (_, _) => ShowPreview());
        menu.Items.Add("Install & user guide", null, (_, _) => InstallationGuide.Open());
        menu.Items.Add("Quit", null, (_, _) => Application.Current.Shutdown());
        var iconPath = Path.Combine(AppContext.BaseDirectory, "Assets", "DepartureBoard.ico");
        icon = File.Exists(iconPath)
            ? new Icon(iconPath)
            : Icon.ExtractAssociatedIcon(Environment.ProcessPath!);
        tray = new Forms.NotifyIcon
        {
            Text = "Departure Board",
            ContextMenuStrip = menu,
            Visible = true,
            Icon = icon,
        };
        tray.DoubleClick += (_, _) => ShowSettings();
        waiting = ThreadPool.RegisterWaitForSingleObject(
            showSettingsSignal,
            (_, _) => Application.Current.Dispatcher.BeginInvoke(ShowSettings),
            null,
            Timeout.Infinite,
            false
        );
        refreshTimer = new DispatcherTimer(
            TimeSpan.FromSeconds(30),
            DispatcherPriority.Background,
            (_, _) => RefreshVisibleData(),
            Application.Current.Dispatcher
        );
        ApplyWallpaper();
    }

    public void ShowSettings()
    {

        if (settingsWindow is null)
        {
            settingsWindow = new SettingsWindow(services, ShowPreview, ApplyWallpaper);
            settingsWindow.Closed += (_, _) => settingsWindow = null;
        }

        settingsWindow.Show();
        settingsWindow.Activate();
    }

    private void RefreshVisibleData()
    {

        if (
            (
                settingsWindow?.IsVisible == true
                && settingsWindow.WindowState != WindowState.Minimized
            )
            || (preview?.IsVisible == true && preview.WindowState != WindowState.Minimized)
            || System.Linq.Enumerable.Any(displays.WallpaperWindows, window => window.Visible)
        )
        {
            _ = services.RefreshAsync();
        }
    }

    private void ShowPreview()
    {

        if (preview is null)
        {
            preview = new BoardWindow(services, false);
            preview.Closed += (_, _) => preview = null;
        }

        preview.Show();
        preview.Activate();
    }

    private bool ApplyWallpaper()
    {

        return displays.SetWallpaper(services.Settings.WallpaperEnabled);
    }

    public void Dispose()
    {

        refreshTimer.Stop();
        displays.Dispose();
        waiting.Unregister(null);
        showSettingsSignal.Dispose();
        tray.Dispose();
        menu.Dispose();
        icon?.Dispose();
    }
}
