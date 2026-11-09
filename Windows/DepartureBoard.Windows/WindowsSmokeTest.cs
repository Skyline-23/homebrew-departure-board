using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using DepartureBoard.Core.Runtime;
using DepartureBoard.Core.Settings;
using DepartureBoard.Windows.Platform;
using DepartureBoard.Windows.Rendering;
using DepartureBoard.Windows.Views;

namespace DepartureBoard.Windows;

internal static class WindowsSmokeTest
{
    public static int Run(string outputDirectory, bool checkDesktop = false)
    {

        Directory.CreateDirectory(outputDirectory);
        File.WriteAllText(Path.Combine(outputDirectory, "progress.txt"), "Started self-test.\n");
        var storage = Path.Combine(outputDirectory, "isolated-data");
        using var services = new AppServices(storage);
        var count = RenderAirports(services, outputDirectory);
        CheckSettings(services);
        CheckPreviewEmbedding(services);
        CheckCredentials();
        CheckFrameUpdates(services, outputDirectory);
        WindowsPerformanceTest.Run(services, outputDirectory);

        if (checkDesktop)
        {
            CheckDesktop(services, outputDirectory);
        }
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

    private static void CheckFrameUpdates(AppServices services, string outputDirectory)
    {

        var time = DateTimeOffset.Parse("2026-11-09T09:00:00Z");
        var session = new BoardSession(services.Catalog, services.Flights);
        var settings = new BoardSettings { Language = "english", Style = "flap" };
        session.Update(settings, time, false);
        var first = session.Frame!;

        if (session.Update(settings, time.AddSeconds(4), false))
        {
            throw new InvalidOperationException("Unchanged sample frames should not redraw.");
        }

        session.Update(settings, time.AddSeconds(15), false);

        if (!ReferenceEquals(first.Rows, session.Frame!.Rows))
        {
            throw new InvalidOperationException("Page changes should reuse the timetable.");
        }

        var renderer = new BoardRenderer(services.Catalog);
        byte[] Render(BoardFrame frame, string name, bool cacheText = true)
        {

            var selectedRenderer = cacheText
                ? renderer
                : new BoardRenderer(services.Catalog, false);
            var visual = new DrawingVisual();
            using (var drawing = visual.RenderOpen())
            {
                selectedRenderer.Draw(drawing, new Size(1600, 900), frame);
            }
            // Materialize glyph rasterization before comparing steady-state pixels.
            SaveImage(visual, Path.Combine(outputDirectory, name + ".png"));
            var bitmap = new RenderTargetBitmap(1600, 900, 96, 96, PixelFormats.Pbgra32);
            bitmap.Render(visual);
            var pixels = new byte[1600 * 900 * 4];
            bitmap.CopyPixels(pixels, 1600 * 4, 0);
            return pixels;
        }

        var reference = Render(first, "flap-uncached", false);
        var firstPixels = Render(first, "flap-first");
        var nextPixels = Render(session.Frame!, "flap-next");

        if (firstPixels.SequenceEqual(nextPixels))
        {
            throw new InvalidOperationException("Split-flap pages must display later departures.");
        }

        var repeated = Render(first, "flap-repeat");

        if (!firstPixels.SequenceEqual(repeated) || !reference.SequenceEqual(repeated))
        {
            var differences = firstPixels.Zip(repeated).Count(pair => pair.First != pair.Second);
            var uncachedDifferences = reference
                .Zip(repeated)
                .Count(pair => pair.First != pair.Second);
            throw new InvalidOperationException(
                $"Cached text changed {differences} bytes; uncached differs by {uncachedDifferences}."
            );
        }

        var dimmed = Render(
            first with
            {
                Settings = first.Settings with { Brightness = 0.35 },
            },
            "flap-dimmed"
        );
        long brightSum = 0;
        long dimSum = 0;

        for (var index = 0; index < repeated.Length; index++)
        {
            if (index % 4 == 3)
            {
                continue;
            }
            brightSum += repeated[index];
            dimSum += dimmed[index];
        }

        if (dimSum >= brightSum / 2)
        {
            throw new InvalidOperationException("Brightness must dim the rendered board.");
        }

        session.Update(settings, time.AddMinutes(1), false);

        if (ReferenceEquals(first.Rows, session.Frame!.Rows))
        {
            throw new InvalidOperationException(
                "Minute changes must refresh sample times and status."
            );
        }

        File.WriteAllText(
            Path.Combine(outputDirectory, "frame-checks.txt"),
            "Sample cadence, row reuse, split-flap pagination and cached pixel stability passed."
        );
    }

    private static void CheckDesktop(AppServices services, string outputDirectory)
    {

        var screenBounds = new System.Drawing.Rectangle(-1920, 0, 1920, 1080);
        var workingArea = new System.Drawing.Rectangle(-1920, 0, 1920, 1032);
        var content = DesktopGeometry.ContentBounds(screenBounds, workingArea);

        if (
            content.X < 0
            || content.Y < 0
            || content.Right > screenBounds.Width
            || content.Bottom >= workingArea.Height
        )
        {
            throw new InvalidOperationException(
                "Wallpaper content must fit above the taskbar on offset monitors."
            );
        }

        using var desktop = new DesktopVisibility();

        if (!desktop.IsCurrent)
        {
            throw new InvalidOperationException(
                "The desktop scope did not match the current desktop."
            );
        }
        using var displays = new DisplayWindows(services);

        if (!displays.SetWallpaper(true))
        {
            throw new InvalidOperationException("Windows Explorer's wallpaper host was not found.");
        }

        var screens = System.Windows.Forms.Screen.AllScreens;

        if (displays.WallpaperWindows.Count != screens.Length)
        {
            throw new InvalidOperationException("Wallpaper did not cover every monitor.");
        }

        var bounds = new System.Collections.Generic.List<object>();

        for (var index = 0; index < screens.Length; index++)
        {
            var handle = displays.WallpaperWindows[index].Handle;

            if (
                NativeMethods.GetParent(handle) == 0
                || !NativeMethods.GetClientRect(handle, out var actual)
                || actual.Right != screens[index].Bounds.Width
                || actual.Bottom != screens[index].Bounds.Height
            )
            {
                throw new InvalidOperationException(
                    "Wallpaper embedding or physical sizing failed."
                );
            }
            bounds.Add(new { width = actual.Right, height = actual.Bottom });
        }
        File.WriteAllText(
            Path.Combine(outputDirectory, "desktop-checks.json"),
            JsonSerializer.Serialize(new { monitors = bounds, wallpaperEmbedding = "passed" })
        );
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
