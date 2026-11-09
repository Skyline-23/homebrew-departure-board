using System;
using Microsoft.Win32;

namespace DepartureBoard.Windows.Platform;

internal static class StartupRegistration
{
    public static void Apply(bool enabled)
    {

        using var key = Registry.CurrentUser.CreateSubKey(
            @"Software\Microsoft\Windows\CurrentVersion\Run"
        );

        if (enabled)
        {
            key.SetValue("DepartureBoard", $"\"{Environment.ProcessPath}\" --background");
        }
        else
        {
            key.DeleteValue("DepartureBoard", false);
        }
    }
}
