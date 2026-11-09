using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Forms;
using System.Windows.Interop;
using System.Windows.Threading;
using DepartureBoard.Windows.Views;

namespace DepartureBoard.Windows.Platform;

internal sealed class DisplayWindows(AppServices services) : IDisposable
{
    private readonly List<BoardWindow> wallpaperWindows = [];

    public IReadOnlyList<BoardWindow> ShowScreenSaver()
    {

        var windows = new List<BoardWindow>();

        foreach (var screen in Screen.AllScreens)
        {
            var window = new BoardWindow(services, true);
            PlaceOnScreen(window, screen);
            window.Show();
            windows.Add(window);
        }

        return windows;
    }

    public BoardWindow ShowPreview(nint parent, bool exitWhenClosed = true)
    {

        if (!NativeMethods.IsWindow(parent))
        {
            throw new ArgumentException("The screen saver preview window no longer exists.");
        }

        var window = EmbeddedWindow();

        void Resize()
        {

            if (!NativeMethods.IsWindow(parent))
            {
                window.Close();
                return;
            }

            if (NativeMethods.GetClientRect(parent, out var bounds))
            {
                WindowEmbedding.Attach(
                    window,
                    parent,
                    0,
                    0,
                    Math.Max(1, bounds.Right),
                    Math.Max(1, bounds.Bottom)
                );
            }
        }

        window.SourceInitialized += (_, _) => Resize();
        window.Show();
        var timer = new DispatcherTimer(
            TimeSpan.FromSeconds(1),
            DispatcherPriority.Background,
            (_, _) => Resize(),
            window.Dispatcher
        );
        window.Closed += (_, _) =>
        {
            timer.Stop();

            if (exitWhenClosed)
            {
                System.Windows.Application.Current.Shutdown();
            }
        };
        return window;
    }

    public bool SetWallpaper(bool enabled)
    {

        Dispose();

        if (!enabled)
        {
            return true;
        }

        var host = WindowEmbedding.DesktopHost();

        if (host == 0)
        {
            return false;
        }

        foreach (var screen in Screen.AllScreens)
        {
            var bounds = screen.Bounds;
            var point = new NativeMethods.NativePoint { X = bounds.Left, Y = bounds.Top };
            NativeMethods.MapWindowPoints(0, host, ref point, 1);
            var window = EmbeddedWindow();
            window.SourceInitialized += (_, _) =>
                WindowEmbedding.Attach(window, host, point.X, point.Y, bounds.Width, bounds.Height);
            window.Show();
            wallpaperWindows.Add(window);
        }

        return true;
    }

    private static BoardWindow EmbeddedWindow(AppServices services)
    {

        return new BoardWindow(services, false)
        {
            WindowStyle = WindowStyle.None,
            ResizeMode = ResizeMode.NoResize,
            ShowInTaskbar = false,
            ShowActivated = false,
        };
    }

    private BoardWindow EmbeddedWindow()
    {

        return EmbeddedWindow(services);
    }

    private static void PlaceOnScreen(Window window, Screen screen)
    {

        // Screen bounds are physical pixels, while WPF uses device-independent units.
        // Position the HWND directly so mixed-DPI monitors keep their correct bounds.
        var bounds = screen.Bounds;
        window.SourceInitialized += (_, _) =>
        {
            var handle = new WindowInteropHelper(window).Handle;
            NativeMethods.SetWindowPos(
                handle,
                0,
                bounds.Left,
                bounds.Top,
                bounds.Width,
                bounds.Height,
                0x0010
            );
        };
    }

    public void Dispose()
    {

        foreach (var window in wallpaperWindows)
        {
            window.Close();
        }

        wallpaperWindows.Clear();
    }
}
