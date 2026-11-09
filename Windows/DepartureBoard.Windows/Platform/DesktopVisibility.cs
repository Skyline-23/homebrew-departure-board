using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;

namespace DepartureBoard.Windows.Platform;

internal sealed class DesktopVisibility : IDisposable
{
    [ComImport, Guid("AA509086-5CA9-4C25-8F95-589D3C07B48A")]
    private class Manager { }

    [
        ComImport,
        Guid("A5CD92FF-29BE-454C-8D04-D82879FB3F1B"),
        InterfaceType(ComInterfaceType.InterfaceIsIUnknown)
    ]
    private interface IManager
    {
        [PreserveSig]
        int IsWindowOnCurrentVirtualDesktop(
            nint window,
            [MarshalAs(UnmanagedType.Bool)] out bool current
        );

        [PreserveSig]
        int GetWindowDesktopId(nint window, out Guid desktop);

        [PreserveSig]
        int MoveWindowToDesktop(nint window, ref Guid desktop);
    }

    private readonly IManager manager = (IManager)new Manager();
    private readonly Window anchor = new()
    {
        WindowStyle = WindowStyle.None,
        ShowInTaskbar = false,
        ShowActivated = false,
        AllowsTransparency = true,
        Opacity = 0,
        Width = 1,
        Height = 1,
        Left = -32000,
        Top = -32000,
    };

    public DesktopVisibility()
    {

        // A real top-level window gives the documented virtual desktop API a
        // stable desktop membership without moving or pinning the user's windows.
        anchor.Show();
    }

    public bool IsCurrent
    {
        get
        {
            var result = manager.IsWindowOnCurrentVirtualDesktop(
                new WindowInteropHelper(anchor).Handle,
                out var current
            );
            Marshal.ThrowExceptionForHR(result);
            return current;
        }
    }

    public void Dispose()
    {

        anchor.Close();
        Marshal.ReleaseComObject(manager);
    }
}
