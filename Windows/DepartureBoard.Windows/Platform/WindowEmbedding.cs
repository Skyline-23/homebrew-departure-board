using System;
using System.Windows;
using System.Windows.Interop;

namespace DepartureBoard.Windows.Platform;

internal static class WindowEmbedding
{
    public static void Attach(
        Window window,
        nint parent,
        int x,
        int y,
        int width,
        int height,
        nint after = default
    )
    {

        var handle = new WindowInteropHelper(window).EnsureHandle();
        Attach(handle, parent, x, y, width, height, after);
    }

    public static void Attach(
        nint handle,
        nint parent,
        int x,
        int y,
        int width,
        int height,
        nint after = default
    )
    {

        const long child = 0x40000000;
        const long popup = 0x80000000;
        var style = NativeMethods.GetWindowLongPtr(handle, -16).ToInt64();
        NativeMethods.SetWindowLongPtr(handle, -16, (nint)((style | child) & ~popup));
        NativeMethods.SetParent(handle, parent);

        if (
            NativeMethods.GetParent(handle) != parent
            || !NativeMethods.SetWindowPos(handle, after, x, y, width, height, 0x0010 | 0x0040)
        )
        {
            throw new System.ComponentModel.Win32Exception(
                System.Runtime.InteropServices.Marshal.GetLastWin32Error(),
                "Could not embed the board window."
            );
        }
    }

    public static nint DesktopHost(out nint after, out bool layered)
    {

        after = 0;
        layered = false;

        var programManager = NativeMethods.FindWindow("Progman", null);

        if (programManager == 0)
        {
            return 0;
        }

        NativeMethods.SendMessageTimeout(programManager, 0x052C, 0, 0, 0, 1000, out _);
        var icons = NativeMethods.FindWindowEx(programManager, 0, "SHELLDLL_DefView", null);
        const long noRedirectionBitmap = 0x00200000;

        if (
            icons != 0
            && (NativeMethods.GetWindowLongPtr(programManager, -20).ToInt64() & noRedirectionBitmap)
                != 0
        )
        {
            // Windows 11's raised desktop composites layered children of Progman.
            // Keep the board below DefView (icons) and above the system wallpaper.
            NativeMethods.SendMessageTimeout(programManager, 0x052C, 0xD, 1, 0, 1000, out _);
            after = icons;
            layered = true;
            return programManager;
        }
        nint host = 0;
        NativeMethods.EnumWindows(
            (window, _) =>
            {
                var view = NativeMethods.FindWindowEx(window, 0, "SHELLDLL_DefView", null);

                if (view != 0)
                {
                    host = NativeMethods.FindWindowEx(0, window, "WorkerW", null);
                }

                return true;
            },
            0
        );
        return host;
    }
}
