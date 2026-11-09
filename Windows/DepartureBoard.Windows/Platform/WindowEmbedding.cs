using System;
using System.Windows;
using System.Windows.Interop;

namespace DepartureBoard.Windows.Platform;

internal static class WindowEmbedding
{
    public static void Attach(Window window, nint parent, int x, int y, int width, int height)
    {

        var handle = new WindowInteropHelper(window).EnsureHandle();
        const long child = 0x40000000;
        const long popup = 0x80000000;
        var style = NativeMethods.GetWindowLongPtr(handle, -16).ToInt64();
        NativeMethods.SetWindowLongPtr(handle, -16, (nint)((style | child) & ~popup));
        NativeMethods.SetParent(handle, parent);
        NativeMethods.SetWindowPos(handle, 0, x, y, width, height, 0x0010 | 0x0040);
    }

    public static nint DesktopHost()
    {

        var programManager = NativeMethods.FindWindow("Progman", null);

        if (programManager == 0)
        {
            return 0;
        }

        NativeMethods.SendMessageTimeout(programManager, 0x052C, 0, 0, 0, 1000, out _);
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
