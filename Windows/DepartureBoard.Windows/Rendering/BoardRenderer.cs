using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Media;
using DepartureBoard.Core.Airports;

namespace DepartureBoard.Windows.Rendering;

internal sealed class BoardRenderer(AirportCatalog catalog)
{
    private readonly Dictionary<string, AirportAdapter> adapters = [];
    private readonly LogoStore logos = new(catalog.ResourceDirectory);
    private static readonly Dictionary<string, double> Weights = new()
    {
        ["time"] = 0.13,
        ["expected"] = 0.12,
        ["flight"] = 0.21,
        ["airline"] = 0.14,
        ["destination"] = 0.30,
        ["terminal"] = 0.07,
        ["counter"] = 0.10,
        ["gate"] = 0.08,
        ["state"] = 0.22,
    };

    public void Draw(DrawingContext context, Size size, BoardFrame frame)
    {

        if (size.Width <= 0 || size.Height <= 0)
        {
            return;
        }

        var logicalWidth = 1600 / frame.Settings.Scale;
        var scale = size.Width / logicalWidth;
        var bounds = new Rect(0, 0, logicalWidth, size.Height / scale);
        context.PushClip(new RectangleGeometry(new Rect(size)));
        context.PushTransform(new ScaleTransform(scale, scale));
        var drawing = new Drawing(context);
        drawing.Fill(bounds, frame.Airport.Data.Text("bg", "080d13"));

        if (frame.Settings.Style == "flap")
        {
            new FlapRenderer(catalog.Strings).Draw(drawing, bounds, frame);
        }
        else
        {
            DrawTable(drawing, bounds, frame);
        }

        context.Pop();
        context.Pop();
    }

    private void DrawTable(Drawing drawing, Rect bounds, BoardFrame frame)
    {

        var airport = frame.Airport;
        var style = airport.Display;
        var adapter = Adapter(airport);
        var rows = adapter.RowCount(bounds, frame);
        var pages = Math.Max(1, (frame.Rows.Count + rows - 1) / rows);
        var page = frame.PageCycle % pages;
        var width = bounds.Width - 40;
        var headingY = adapter.HeaderHeight(bounds, frame.Settings.Scale) + 4;
        var tableY = headingY + adapter.ColumnHeight;
        var bottom = bounds.Height - Math.Max(29, style.Number("footerHeight") + 3);
        var rowHeight = (bottom - tableY) / rows;
        var fontSize =
            Math.Min(36, Math.Min(rowHeight * 0.78, width / 34)) * style.Number("rowFontScale", 1);
        var totalWeight = airport.Columns.Sum(column => Weight(airport, column));
        var cells = new AirportCellRenderer(catalog.Strings, logos);
        adapter.Header(drawing, bounds, frame);
        drawing.Fill(
            new Rect(20, headingY, width, adapter.ColumnHeight - 2),
            style.Text("columnBand", "101c29")
        );
        DrawColumnLabels(drawing, frame, adapter, headingY, width, totalWeight);

        for (var index = 0; index < rows && page * rows + index < frame.Rows.Count; index++)
        {
            var row = frame.Rows[page * rows + index];
            var top = tableY + index * rowHeight;
            var colors = style.Strings("rowColors");
            drawing.Fill(new Rect(20, top, width, rowHeight - 1), colors[index % colors.Length]);
            var left = 20.0;

            foreach (var column in airport.Columns)
            {
                var cellWidth = width * Weight(airport, column) / totalWeight;
                var fill = style.Child("columnFills").Text(column);

                if (fill.Length > 0)
                {
                    drawing.Fill(new Rect(left, top, cellWidth - 1, rowHeight - 1), fill);
                }

                var rule = style.Text("verticalRules");

                if (rule.Length > 0)
                {
                    drawing.Fill(new Rect(left + cellWidth - 1, top, 1, rowHeight), rule);
                }

                cells.Draw(
                    drawing,
                    frame,
                    row,
                    column,
                    new Rect(left + 5, top + 1, cellWidth - 9, rowHeight - 3),
                    fontSize,
                    index
                );
                left += cellWidth;
            }
        }

        if (frame.Rows.Count == 0)
        {
            drawing.Text(
                catalog.Strings.Get(
                    frame.Settings.SampleData ? "data.noDepartures" : "data.configure",
                    frame.Language
                ),
                new Rect(100, tableY + 70, bounds.Width - 200, 80),
                26,
                "b9c9d4",
                alignment: TextAlignment.Center
            );
        }

        adapter.Footer(drawing, bounds, frame, page, pages);
    }

    private void DrawColumnLabels(
        Drawing drawing,
        BoardFrame frame,
        AirportAdapter adapter,
        double top,
        double width,
        double totalWeight
    )
    {

        var style = frame.Airport.Display;
        var languages = style.Strings("columnHeaderLanguages");
        var count = Math.Max(1, languages.Length);
        var left = 20.0;

        foreach (var column in frame.Airport.Columns)
        {
            var cellWidth = width * Weight(frame.Airport, column) / totalWeight;
            var key = style.Child("columnLabels").Text(column, "column." + column);

            for (var line = 0; line < count; line++)
            {
                var language = languages.Length == 0 ? frame.Language : languages[line];
                drawing.Text(
                    catalog.Strings.Get(key, language),
                    new Rect(
                        left + 5,
                        top + line * adapter.ColumnHeight / count,
                        cellWidth - 8,
                        adapter.ColumnHeight / count - 2
                    ),
                    count > 1 ? 18 : Math.Min(24, width / 37),
                    style.Text("columnInk", "ffffff"),
                    style.Text("bodyFont")
                );
            }

            left += cellWidth;
        }
    }

    private AirportAdapter Adapter(AirportProfile airport)
    {

        if (!adapters.TryGetValue(airport.Code, out var adapter))
        {
            adapter = AirportAdapter.Create(airport, catalog.Strings);
            adapters[airport.Code] = adapter;
        }

        return adapter;
    }

    private static double Weight(AirportProfile airport, string column)
    {

        return airport
            .Display.Child("columnWeights")
            .Number(column, Weights.GetValueOrDefault(column, 0.1));
    }
}
