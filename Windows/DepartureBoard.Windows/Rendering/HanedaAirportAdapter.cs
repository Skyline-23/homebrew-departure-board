using System;
using System.Globalization;
using System.Linq;
using System.Windows;
using DepartureBoard.Core.Airports;
using DepartureBoard.Core.Flights;

namespace DepartureBoard.Windows.Rendering;

internal sealed class HanedaAirportAdapter(
    AirportProfile airport,
    StringCatalog strings,
    LogoStore? logos = null
) : ProfileAirportAdapter(airport, strings)
{
    private LogoStore? logoStore = logos;

    public override double HeaderHeight(Rect bounds, double scale)
    {

        return bounds.Width > bounds.Height
            ? Math.Max(
                Math.Min(210, bounds.Height * 0.19),
                Airport.Display.Number("minimumHeaderHeight")
            )
            : base.HeaderHeight(bounds, scale);
    }

    public override void Header(Drawing drawing, Rect bounds, BoardFrame frame)
    {

        var height = HeaderHeight(bounds, frame.Settings.Scale);
        var unit = Math.Min(1.6, height / 230);
        var ink = Airport.Display.Text("headerInk", "ffffff");
        drawing.Fill(new Rect(0, 0, bounds.Width, height), Airport.Data.Text("header"));

        if (height >= 140)
        {
            drawing.Text(
                Strings.Get("heading.checkinInformation", frame.Language),
                new Rect(26, 3, 1400, 30 * unit),
                23 * unit,
                ink,
                bold: true
            );
            Counters(
                drawing,
                new Rect(24, 38 * unit, bounds.Width - 48, height - 93 * unit),
                frame
            );
        }

        drawing.Fill(new Rect(0, height - 45 * unit, bounds.Width, 45 * unit), "000000");
        drawing.Fill(new Rect(0, height - 3, bounds.Width, 3), "8dd856");
        drawing.Plane(new Rect(25, height - 38 * unit, 30 * unit, 30 * unit), "a9e482");
        drawing.Text(
            Strings.Get("heading.departures", frame.Language),
            new Rect(68 * unit, height - 42 * unit, 1000, 37 * unit),
            28 * unit,
            ink,
            bold: true
        );
        drawing.Text(
            Airport.LocalTime(frame.Time).ToString("HH:mm", CultureInfo.InvariantCulture),
            new Rect(bounds.Width - 190 * unit, height - 42 * unit, 164 * unit, 37 * unit),
            28 * unit,
            "a9e482",
            bold: true,
            alignment: TextAlignment.Right
        );
    }

    private void Counters(Drawing drawing, Rect bounds, BoardFrame frame)
    {

        var counters = new[]
        {
            "N",
            "M",
            "L",
            "K",
            "J",
            "I",
            "H",
            "G",
            "F",
            "",
            "E",
            "D",
            "C",
            "B",
            "A",
        };
        var width = (bounds.Width - 24) / counters.Length;
        var unit = Math.Min(1.25, bounds.Height / 120);
        logoStore ??= new LogoStore(System.IO.Path.Combine(AppContext.BaseDirectory, "Resources"));

        for (var index = 0; index < counters.Length; index++)
        {
            var letter = counters[index];

            if (letter.Length == 0)
            {
                continue;
            }

            var x = bounds.X + 12 + index * width;
            var top = bounds.Y + bounds.Height * 0.25;
            var height = bounds.Height * 0.57;
            var carriers = frame
                .Rows.Where(row => row.Counter.Contains(letter, StringComparison.Ordinal))
                .Select(row => row with { Flight = row.OperatorFlight })
                .DistinctBy(row => row.Flight.Split(' ')[0])
                .Select(row => logoStore.Get(row))
                .Where(logo => logo is not null)
                .Take(2)
                .ToArray();
            drawing.Fill(new Rect(x, top, width - 6, height), "d8e5eb");
            var slotHeight = Math.Max(0, height - 28 * unit - 8) / 2;

            for (var slot = 0; slot < carriers.Length; slot++)
            {
                drawing.Image(
                    carriers[slot]!,
                    new Rect(
                        x + 8,
                        top + 4 + slot * slotHeight + (carriers.Length == 1 ? slotHeight / 2 : 0),
                        width - 22,
                        slotHeight
                    )
                );
            }

            drawing.Fill(new Rect(x, top + height - 28 * unit, width - 6, 28 * unit), "bcd3e2");
            drawing.Text(
                letter,
                new Rect(x, top + height - 27 * unit, width - 6, 27 * unit),
                23 * unit,
                "101d2d",
                bold: true,
                alignment: TextAlignment.Center
            );
        }

        drawing.Text(
            Strings.Get("heading.securityNorth", frame.Language),
            new Rect(bounds.X + width * 2, bounds.Y + 2, width * 4, 27 * unit),
            17 * unit,
            "ffffff",
            bold: true,
            alignment: TextAlignment.Center
        );
        drawing.Text(
            Strings.Get("heading.securityCentral", frame.Language),
            new Rect(bounds.X + width * 8, bounds.Y + 2, width * 5, 27 * unit),
            17 * unit,
            "ffffff",
            bold: true,
            alignment: TextAlignment.Center
        );
    }
}
