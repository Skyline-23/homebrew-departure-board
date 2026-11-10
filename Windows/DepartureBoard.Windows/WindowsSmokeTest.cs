using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using DepartureBoard.Core.Diagnostics;
using DepartureBoard.Core.Runtime;
using DepartureBoard.Core.Settings;
using DepartureBoard.Windows.Platform;
using DepartureBoard.Windows.Rendering;
using DepartureBoard.Windows.Views;

namespace DepartureBoard.Windows;

internal static class WindowsSmokeTest
{
    public static int Run(
        string outputDirectory,
        bool checkDesktop = false,
        bool displayOnly = false
    )
    {

        Directory.CreateDirectory(outputDirectory);
        File.WriteAllText(Path.Combine(outputDirectory, "progress.txt"), "Started self-test.\n");
        var storage = Path.Combine(outputDirectory, "isolated-data");
        using var services = new AppServices(storage);

        if (displayOnly)
        {
            if (!checkDesktop)
            {
                throw new ArgumentException("Display-only checks require --desktop.");
            }
            services.UsePreviewSettings(new BoardSettings { Airport = "ICN", SampleData = true });
            CheckSettings(services, outputDirectory);
            CheckDesktop(services, outputDirectory);
            File.WriteAllText(
                Path.Combine(outputDirectory, "result.txt"),
                "Desktop layout validation passed."
            );
            return 0;
        }
        var count = RenderAirports(services, outputDirectory);
        CheckSettings(services, outputDirectory);
        CheckPreviewEmbedding(services);
        CheckCredentials();
        CheckFrameUpdates(services, outputDirectory);
        CheckDiagnosticTransitions(services);
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

    private static void CaptureSettings(FrameworkElement content, string destination)
    {

        var bitmap = new RenderTargetBitmap(
            (int)Math.Ceiling(content.ActualWidth),
            (int)Math.Ceiling(content.ActualHeight),
            96,
            96,
            PixelFormats.Pbgra32
        );
        var visual = new DrawingVisual();
        using (var drawing = visual.RenderOpen())
        {
            drawing.DrawRectangle(
                Brushes.White,
                null,
                new Rect(0, 0, content.ActualWidth, content.ActualHeight)
            );
            drawing.DrawRectangle(
                new VisualBrush(content),
                null,
                new Rect(0, 0, content.ActualWidth, content.ActualHeight)
            );
        }
        bitmap.Render(visual);
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using (var stream = File.Create(destination))
        {
            encoder.Save(stream);
        }
    }

    private static void CheckSettings(AppServices services, string outputDirectory)
    {

        services.UsePreviewSettings(new BoardSettings { Airport = "ICN", SampleData = true });
        var settings = new SettingsWindow(services, () => { }, () => true);
        settings.Show();
        settings.UpdateLayout();
        var content = (FrameworkElement)settings.Content;
        CaptureSettings(content, Path.Combine(outputDirectory, "settings-window.png"));
        var scroll = ((System.Windows.Controls.Grid)content)
            .Children.OfType<System.Windows.Controls.ScrollViewer>()
            .Single();
        scroll.ScrollToBottom();
        settings.UpdateLayout();
        CaptureSettings(content, Path.Combine(outputDirectory, "settings-data.png"));
        settings.Width = 560;
        settings.Height = 420;
        settings.UpdateLayout();
        CaptureSettings(content, Path.Combine(outputDirectory, "settings-compact.png"));

        foreach (var language in new[] { "en", "ko" })
        {
            if (!File.Exists(InstallationGuide.PathForLanguage(language)))
            {
                throw new InvalidOperationException("Bundled installation guide is missing.");
            }
        }

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

        PumpDesktop();

        for (var index = 0; index < screens.Length; index++)
        {
            CaptureMonitor(
                screens[index],
                Path.Combine(outputDirectory, $"monitor-{index}-wallpaper.png")
            );
        }
        var previewChecks = new List<object>();
        var previewWindow = new BoardWindow(services, false);
        previewWindow.Show();
        var previewHandle = new WindowInteropHelper(previewWindow).Handle;

        foreach (var screen in screens)
        {
            NativeMethods.SetWindowPos(
                previewHandle,
                0,
                screen.Bounds.Left + 30,
                screen.Bounds.Top + 30,
                900,
                600,
                0x0014
            );
            PumpDesktop();
            var dpi = NativeMethods.GetDpiForWindow(previewHandle);
            var scale = VisualTreeHelper.GetDpi(previewWindow).DpiScaleX;

            if (Math.Abs(scale * 96 - dpi) > 1)
            {
                throw new InvalidOperationException(
                    "Preview scaling did not follow its monitor DPI."
                );
            }
            NativeMethods.GetWindowRect(previewHandle, out var actual);

            if (
                actual.Left < screen.Bounds.Left
                || actual.Top < screen.Bounds.Top
                || actual.Right > screen.Bounds.Right
                || actual.Bottom > screen.Bounds.Bottom
            )
            {
                throw new InvalidOperationException("Preview moved outside its monitor.");
            }
            previewChecks.Add(
                new
                {
                    screen.DeviceName,
                    dpi,
                    scale,
                    actual.Left,
                    actual.Top,
                    actual.Right,
                    actual.Bottom,
                }
            );
        }
        previewWindow.Close();
        var saverBounds = new List<object>();
        var savers = displays.ShowScreenSaver();

        for (var index = 0; index < screens.Length; index++)
        {
            var handle = new WindowInteropHelper(savers[index]).Handle;
            var expected = screens[index].Bounds;

            if (
                !NativeMethods.GetWindowRect(handle, out var actual)
                || actual.Left != expected.Left
                || actual.Top != expected.Top
                || actual.Right - actual.Left != expected.Width
                || actual.Bottom - actual.Top != expected.Height
            )
            {
                throw new InvalidOperationException(
                    "Screen saver does not fit physical monitor bounds."
                );
            }
            saverBounds.Add(
                new
                {
                    device = screens[index].DeviceName,
                    expected.X,
                    expected.Y,
                    expected.Width,
                    expected.Height,
                    dpi = NativeMethods.GetDpiForWindow(handle),
                    wpfScale = VisualTreeHelper.GetDpi(savers[index]).DpiScaleX,
                }
            );
        }
        PumpDesktop();

        for (var index = 0; index < screens.Length; index++)
        {
            CaptureMonitor(
                screens[index],
                Path.Combine(outputDirectory, $"monitor-{index}-screensaver.png")
            );
        }

        foreach (var saver in savers)
        {
            saver.Close();
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
        displays.Dispose();
        CheckStillWallpaper(services, screens, outputDirectory);
        File.WriteAllText(
            Path.Combine(outputDirectory, "desktop-checks.json"),
            JsonSerializer.Serialize(
                new
                {
                    monitors = bounds,
                    screenSavers = saverBounds,
                    previewMoves = previewChecks,
                    wallpaperEmbedding = "passed",
                }
            )
        );
    }

    private static void CheckStillWallpaper(
        AppServices services,
        System.Windows.Forms.Screen[] screens,
        string directory
    )
    {

        using var desktop = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(
            @"Control Panel\Desktop",
            true
        )!;
        var names = new[] { "Wallpaper", "WallpaperStyle", "TileWallpaper" };
        var original = names.ToDictionary(name => name, name => desktop.GetValue(name));
        var imagePath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "DepartureBoard",
            "Wallpaper.png"
        );
        var image = File.Exists(imagePath) ? File.ReadAllBytes(imagePath) : null;

        try
        {
            WallpaperSnapshot.Apply(services);

            for (var tick = 0; tick < 20; tick++)
            {
                PumpDesktop();
            }

            for (var index = 0; index < screens.Length; index++)
            {
                CaptureMonitor(
                    screens[index],
                    Path.Combine(directory, $"monitor-{index}-still.png")
                );
            }
        }
        finally
        {
            if (image is not null)
            {
                File.WriteAllBytes(imagePath, image);
            }

            foreach (var name in names)
            {
                if (original[name] is { } value)
                {
                    desktop.SetValue(name, value);
                }
                else
                {
                    desktop.DeleteValue(name, false);
                }
            }

            if (
                !NativeMethods.SystemParametersInfo(20, 0, original["Wallpaper"] as string ?? "", 3)
            )
            {
                throw new System.ComponentModel.Win32Exception(
                    System.Runtime.InteropServices.Marshal.GetLastWin32Error()
                );
            }

            if (image is null && File.Exists(imagePath))
            {
                File.Delete(imagePath);
            }
        }
    }

    private static void PumpDesktop()
    {

        var frame = new System.Windows.Threading.DispatcherFrame();
        var timer = new System.Windows.Threading.DispatcherTimer(
            TimeSpan.FromMilliseconds(350),
            System.Windows.Threading.DispatcherPriority.Background,
            (_, _) => frame.Continue = false,
            System.Windows.Threading.Dispatcher.CurrentDispatcher
        );
        System.Windows.Threading.Dispatcher.PushFrame(frame);
        timer.Stop();
    }

    private static void CaptureMonitor(System.Windows.Forms.Screen screen, string path)
    {

        using var bitmap = new System.Drawing.Bitmap(screen.Bounds.Width, screen.Bounds.Height);
        using var graphics = System.Drawing.Graphics.FromImage(bitmap);
        graphics.CopyFromScreen(
            screen.Bounds.Location,
            System.Drawing.Point.Empty,
            screen.Bounds.Size
        );
        bitmap.Save(path, System.Drawing.Imaging.ImageFormat.Png);
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

    private static void CheckDiagnosticTransitions(AppServices services)
    {

        var events = new CapturedDiagnostics();
        var diagnostics = new BoardDiagnostics(events, "test");
        var session = new BoardSession(services.Catalog, services.Flights);
        session.Update(new BoardSettings(), DateTimeOffset.UtcNow, false);
        var ready = session.Frame!;
        var loading = ready with { Rows = [], EmptyMessage = "data.loading" };
        diagnostics.Presented(loading);

        for (var tick = 0; tick < 60; tick++)
        {
            diagnostics.Presented(loading with { Time = loading.Time.AddSeconds(tick) });
        }

        diagnostics.Presented(ready);
        diagnostics.Presented(ready with { PageCycle = ready.PageCycle + 1 });

        if (
            events.Entries.Count != 2
            || events.Entries[0].State != "data.loading"
            || events.Entries[1].State != "ready"
        )
        {
            throw new InvalidOperationException(
                "Diagnostics must record transitions without logging every frame."
            );
        }
    }

    private sealed class CapturedDiagnostics : IDiagnosticSink
    {
        public List<DiagnosticEvent> Entries { get; } = [];

        public void Write(DiagnosticEvent entry)
        {

            Entries.Add(entry);
        }
    }
}
