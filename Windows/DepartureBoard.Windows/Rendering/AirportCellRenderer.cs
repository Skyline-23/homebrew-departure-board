using System;
using System.Collections.Generic;
using System.Windows;
using DepartureBoard.Core.Airports;
using DepartureBoard.Core.Flights;

namespace DepartureBoard.Windows.Rendering;

internal sealed class AirportCellRenderer(StringCatalog strings, LogoStore logos)
{
    private static readonly Dictionary<string, string> StatusColors = new()
    {
        ["boarding"] = "7bddbe",
        ["closing"] = "ffd653",
        ["gate"] = "f4f6f7",
        ["checkin"] = "f4f6f7",
        ["delayed"] = "ffd653",
        ["cancelled"] = "ff7780",
    };

    public void Draw(
        Drawing drawing,
        BoardFrame frame,
        BoardRow row,
        string column,
        Rect bounds,
        double size,
        int rowIndex
    )
    {

        var style = frame.Airport.Display;
        var rowInks = style.Strings("rowInkColors");
        var ink =
            rowInks.Length > 0
                ? rowInks[rowIndex % rowInks.Length]
                : style.Text("textColor", "ffffff");
        var value = Value(row, column, frame.Language);

        if (column == "destination")
        {
            ink = style.Text("destinationColor", ink);
            value = style.Flag("uppercaseDestinations") ? value.ToUpperInvariant() : value;

            if (style.Flag("stackedDestination"))
            {
                drawing.Text(
                    value,
                    new Rect(bounds.X, bounds.Y, bounds.Width, bounds.Height * 0.57),
                    size * 0.9,
                    ink,
                    style.Text("bodyFont")
                );
                drawing.Text(
                    row.Flight,
                    new Rect(
                        bounds.X,
                        bounds.Y + bounds.Height * 0.57,
                        bounds.Width,
                        bounds.Height * 0.43
                    ),
                    size * 0.62,
                    style.Text("textColor", ink),
                    style.Text("bodyFont")
                );
                return;
            }
        }

        if (column == "state")
        {
            if (
                !style.Flag("statusUsesRowInk")
                && StatusColors.TryGetValue(row.Status, out var statusColor)
            )
            {
                ink = statusColor;
            }

            ink = style.Child("statusColors").Text(row.Status, ink);
            var fill = style.Child("statusFills").Text(row.Status);

            if (fill.Length > 0 && value.Length > 0)
            {
                drawing.Fill(bounds, fill);
                ink = style.Text("statusFillInk", "ffffff");
            }

            size *= 0.88;
        }

        if (column == "expected")
        {
            ink = "ffd653";
        }

        if (column == "time" && rowInks.Length == 0)
        {
            ink = style.Text("timeColor", ink);
        }

        if (column == "gate" && style.Flag("gateIncludesTerminal") && row.Terminal.Length > 0)
        {
            value = row.Terminal + " · " + strings.ValueOrPlaceholder(row.Gate, frame.Language);
        }

        if (column == "airline" || (column == "flight" && style.Flag("airlineBadge")))
        {
            var logo = logos.Get(row);

            if (logo is not null)
            {
                var width = column == "airline" ? bounds.Width : Math.Min(74, bounds.Width * 0.32);
                drawing.Image(logo, new Rect(bounds.X, bounds.Y + 2, width, bounds.Height - 4));

                if (column == "airline")
                {
                    return;
                }

                bounds = new Rect(
                    bounds.X + width + 5,
                    bounds.Y,
                    bounds.Width - width - 5,
                    bounds.Height
                );
            }
        }

        if (value.Length == 0)
        {
            value = style.Child("emptyFields").Text(column);
        }

        if (column is "gate" or "terminal" or "counter")
        {
            value = strings.ValueOrPlaceholder(value, frame.Language);
        }

        if (column == "gate" && style.Flag("gateHighlight"))
        {
            drawing.Fill(bounds, "f4ec7b");
            ink = "17221a";
        }

        ink = style.Child("columnInkColors").Text(column, ink);

        if (column is "time" or "expected" or "flight" or "gate")
        {
            size = Math.Min(size, bounds.Width / Math.Max(2.6, value.Length * 0.60));
        }

        drawing.Text(value, bounds, size, ink, style.Text("bodyFont"));
    }

    private string Value(BoardRow row, string column, string language)
    {

        return column switch
        {
            "time" => row.Time,
            "expected" => row.Expected,
            "flight" => row.Flight,
            "destination" => row.Destination,
            "gate" => row.Gate,
            "terminal" => row.Terminal,
            "counter" => row.Counter,
            "airline" => row.Airline,
            "state" => strings.Get(
                "status." + (row.Status.Length == 0 ? "unknown" : row.Status),
                language
            ),
            _ => "",
        };
    }
}
