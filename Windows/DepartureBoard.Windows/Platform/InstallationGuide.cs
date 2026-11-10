using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;

namespace DepartureBoard.Windows.Platform;

internal static class InstallationGuide
{
    internal static string PathForLanguage(string language)
    {

        var name = language.StartsWith("ko", StringComparison.OrdinalIgnoreCase)
            ? "ko.html"
            : "index.html";
        return Path.Combine(AppContext.BaseDirectory, "Resources", "Guide", name);
    }

    public static void Open()
    {

        var path = PathForLanguage(CultureInfo.CurrentUICulture.Name);

        if (!File.Exists(path))
        {
            throw new FileNotFoundException(
                "Reinstall the complete Departure Board package to restore its guide.",
                path
            );
        }
        Process.Start(new ProcessStartInfo(new Uri(path).AbsoluteUri) { UseShellExecute = true });
    }
}
