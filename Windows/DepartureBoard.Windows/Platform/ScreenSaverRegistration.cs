using System;
using System.IO;
using Microsoft.Win32;

namespace DepartureBoard.Windows.Platform;

internal static class ScreenSaverRegistration
{
    public static void Register()
    {

        var executable =
            Environment.ProcessPath
            ?? throw new InvalidOperationException("The application path is unavailable.");
        var saver = Path.Combine(AppContext.BaseDirectory, "DepartureBoard.scr");

        if (!File.Exists(saver))
        {
            File.Copy(executable, saver);
        }

        using var desktop = Registry.CurrentUser.CreateSubKey(@"Control Panel\Desktop");
        desktop.SetValue("SCRNSAVE.EXE", saver);
        desktop.SetValue("ScreenSaveActive", "1");
    }
}
