using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using DepartureBoard.Core.Settings;
using DepartureBoard.Windows.Rendering;

namespace DepartureBoard.Windows;

internal static class WindowsPerformanceTest
{
    public static void Run(AppServices services, string outputDirectory)
    {

        var measurements = new List<object>();
        var start = DateTimeOffset.Parse("2026-11-09T09:00:00Z");

        foreach (var airport in new[] { "ICN", "HND", "JFK", "LHR" })
        {
            foreach (var width in new[] { 1920, 3840 })
            {
                var size = new Size(width, width * 9 / 16);
                var settings = new BoardSettings
                {
                    Airport = airport,
                    Style = airport == "LHR" ? "flap" : "auto",
                };
                var session = new BoardSession(services.Catalog, services.Flights);
                var renderer = new BoardRenderer(services.Catalog);
                var visual = new DrawingVisual();
                session.Update(settings, start, false);

                // Warm font and logo loading before measuring steady-state drawing.

                for (var warm = 0; warm < 3; warm++)
                {
                    using var drawing = visual.RenderOpen();
                    renderer.Draw(drawing, size, session.Frame!);
                }

                var allocated = GC.GetAllocatedBytesForCurrentThread();
                var watch = Stopwatch.StartNew();
                var redraws = 0;

                for (var second = 1; second <= 120; second++)
                {
                    if (session.Update(settings, start.AddSeconds(second), false))
                    {
                        using var drawing = visual.RenderOpen();
                        renderer.Draw(drawing, size, session.Frame!);
                        redraws++;
                    }
                }

                watch.Stop();
                allocated = GC.GetAllocatedBytesForCurrentThread() - allocated;
                var bitmap = new RenderTargetBitmap(
                    width,
                    (int)size.Height,
                    96,
                    96,
                    PixelFormats.Pbgra32
                );
                var raster = Stopwatch.StartNew();
                bitmap.Render(visual);
                raster.Stop();
                measurements.Add(
                    new
                    {
                        airport,
                        settings.Style,
                        width,
                        simulatedSeconds = 120,
                        redraws,
                        drawingMilliseconds = watch.Elapsed.TotalMilliseconds,
                        allocatedBytes = allocated,
                        rasterMilliseconds = raster.Elapsed.TotalMilliseconds,
                    }
                );
            }
        }

        File.WriteAllText(
            Path.Combine(outputDirectory, "performance.json"),
            JsonSerializer.Serialize(
                new
                {
                    description = "Warm WPF drawing commands over 120 simulated seconds; one software bitmap raster per case. Not GPU frame latency.",
                    renderingTier = RenderCapability.Tier >> 16,
                    runtime = Environment.Version.ToString(),
                    measurements,
                },
                new JsonSerializerOptions { WriteIndented = true }
            )
        );
    }
}
