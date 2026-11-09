using System;
using System.IO;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using DepartureBoard.Core.Runtime;
using DepartureBoard.Core.Settings;
using DepartureBoard.Windows.Platform;
using DepartureBoard.Windows.Views;

namespace DepartureBoard.Windows;

internal static class WindowsSmokeTest
{
    public static int Run(string outputDirectory)
    {

        Directory.CreateDirectory(outputDirectory);
        File.WriteAllText(Path.Combine(outputDirectory, "progress.txt"), "Started self-test.\n");
        var storage = Path.Combine(outputDirectory, "isolated-data");
        using var services = new AppServices(storage);
        var count = RenderAirports(services, outputDirectory);
        CheckSettings(services);
        CheckPreviewEmbedding(services);
        CheckCredentials();
        File.WriteAllText(
            Path.Combine(outputDirectory, "result.txt"),
            $"Rendered {count} airport images; settings and native preview embedding passed."
        );
        return 0;
    }

    private static int RenderAirports(AppServices services, string outputDirectory)
    {

        var fixedTime = DateTimeOffset.Parse(
            "2026-11-09T09:00:00Z",
            System.Globalization.CultureInfo.InvariantCulture
        );
        var count = 0;

        foreach (var airport in services.Catalog.Airports)
        {
            foreach (var language in new[] { "english", "native" })
            {
                services.UsePreviewSettings(
                    new BoardSettings { Airport = airport.Code, Language = language }
                );
                var surface = new BoardSurface(services) { ReferenceTime = fixedTime };
                surface.Measure(new Size(1600, 900));
                surface.Arrange(new Rect(0, 0, 1600, 900));
                surface.Tick();
                surface.UpdateLayout();
                var path = Path.Combine(outputDirectory, airport.Code + "-" + language + ".png");
                SaveImage(surface, path);
                count++;
                File.AppendAllText(
                    Path.Combine(outputDirectory, "progress.txt"),
                    airport.Code + " " + language + " rendered.\n"
                );
            }
        }

        if (count != 80)
        {
            throw new InvalidOperationException("Expected two images for each of 40 airports.");
        }

        return count;
    }

    private static void SaveImage(Visual visual, string path)
    {

        var bitmap = new RenderTargetBitmap(1600, 900, 96, 96, PixelFormats.Pbgra32);
        bitmap.Render(visual);
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var stream = File.Create(path);
        encoder.Save(stream);

        if (stream.Length < 10000)
        {
            throw new InvalidOperationException("The board image appears to be empty: " + path);
        }
    }

    private static void CheckSettings(AppServices services)
    {

        var settings = new SettingsWindow(services, () => { }, () => true);

        if (settings.AirportCount != 40 || LaunchOptions.Parse(["/p:12345"]).PreviewParent != 12345)
        {
            throw new InvalidOperationException("Windows integration smoke checks failed.");
        }

        settings.Close();
    }

    private static void CheckPreviewEmbedding(AppServices services)
    {

        using var parent = new HwndSource(
            new HwndSourceParameters("Preview test host")
            {
                Width = 640,
                Height = 360,
                WindowStyle = 0x10000000,
            }
        );
        using var displays = new DisplayWindows(services);
        var preview = displays.ShowPreview(parent.Handle, false);
        var handle = new WindowInteropHelper(preview).Handle;
        var embedded = NativeMethods.GetParent(handle) == parent.Handle;
        var parentMeasured = NativeMethods.GetClientRect(parent.Handle, out var expected);
        var childMeasured = NativeMethods.GetClientRect(handle, out var bounds);
        var sized =
            parentMeasured
            && childMeasured
            && bounds.Right == expected.Right
            && bounds.Bottom == expected.Bottom;
        preview.Close();

        if (!embedded || !sized)
        {
            throw new InvalidOperationException(
                $"Preview parent matched: {embedded}; child: {bounds.Right} x {bounds.Bottom}; "
                    + $"parent: {expected.Right} x {expected.Bottom}."
            );
        }
    }

    private static void CheckCredentials()
    {

        var credentials = new CredentialStore("DepartureBoard.SmokeTest." + Guid.NewGuid());

        try
        {
            credentials.Save("test-value");
            credentials.Save("");

            if (credentials.Read() != "test-value")
            {
                throw new InvalidOperationException("Credential Manager round trip failed.");
            }
        }
        finally
        {
            credentials.Delete();
        }
    }
}
