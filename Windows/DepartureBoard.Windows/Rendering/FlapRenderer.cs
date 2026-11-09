using System;
using System.Globalization;
using System.Windows;
using DepartureBoard.Core.Airports;

namespace DepartureBoard.Windows.Rendering;

internal sealed class FlapRenderer(StringCatalog strings)
{
    public void Draw(Drawing drawing, Rect bounds, BoardFrame frame)
    {

        drawing.Fill(bounds, "111416");
        drawing.Fill(new Rect(0, 0, bounds.Width, 112), frame.Airport.Data.Text("header"));
        drawing.Plane(new Rect(34, 30, 52, 52), "f6f7f4");
        drawing.Text(
            strings.Get("heading.departures", frame.Language),
            new Rect(106, 14, 990, 62),
            42,
            "f6f7f4",
            bold: true
        );
        drawing.Text(
            frame.Airport.LocalTime(frame.Time).ToString("HH:mm", CultureInfo.InvariantCulture),
            new Rect(bounds.Width - 306, 10, 270, 65),
            57,
            "f6f7f4",
            bold: true,
            alignment: TextAlignment.Right
        );
        var horizontal = bounds.Width / 1600;
        var positions = new[] { 34.0, 196, 760, 1085, 1208 };
        var widths = new[] { 142.0, 541, 304, 100, 356 };
        var counts = new[] { 5, 20, 10, 3, 15 };
        var labels = new[] { "TIME", "DESTINATION", "AIRLINE / FLIGHT", "GATE", "REMARKS" };

        for (var index = 0; index < labels.Length; index++)
        {
            drawing.Text(
                labels[index],
                new Rect(positions[index] * horizontal, 126, widths[index] * horizontal, 26),
                16,
                "9da8aa",
                bold: true
            );
        }

        var rowCount =
            frame.Settings.Density > 0
                ? Math.Clamp(frame.Settings.Density, 6, 32)
                : Math.Min(32, (int)Math.Ceiling(16 / frame.Settings.Scale));
        var rowHeight = (bounds.Height - 218) / rowCount;

        for (var index = 0; index < rowCount && index < frame.Rows.Count; index++)
        {
            var row = frame.Rows[index];
            var values = new[]
            {
                row.Time,
                row.Destination.ToUpperInvariant(),
                row.Flight,
                row.Gate,
                strings.Get("status." + row.Status, frame.Language).ToUpperInvariant(),
            };

            for (var column = 0; column < values.Length; column++)
            {
                DrawFlaps(
                    drawing,
                    values[column],
                    new Rect(
                        positions[column] * horizontal,
                        167 + index * rowHeight,
                        widths[column] * horizontal,
                        rowHeight - 9
                    ),
                    counts[column],
                    column == 0 ? "ffdc64" : "e8e7df"
                );
            }
        }
    }

    private static void DrawFlaps(
        Drawing drawing,
        string value,
        Rect bounds,
        int cells,
        string color
    )
    {

        var width = bounds.Width / cells;

        for (var index = 0; index < cells; index++)
        {
            var tile = new Rect(
                bounds.X + index * width,
                bounds.Y,
                width - Math.Max(1, width * 0.065),
                bounds.Height - 3
            );
            drawing.Fill(tile, "292e33");
            drawing.Text(
                index < value.Length ? value[index].ToString() : " ",
                tile,
                Math.Min(width * 1.1, bounds.Height * 0.79),
                color,
                "Menlo-Bold",
                true,
                TextAlignment.Center
            );
            drawing.Fill(new Rect(tile.X, tile.Y + tile.Height / 2, tile.Width, 1.6), "090b0d");
        }
    }
}
