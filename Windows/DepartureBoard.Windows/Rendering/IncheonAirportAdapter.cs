using System.Globalization;
using System.Windows;
using DepartureBoard.Core.Airports;

namespace DepartureBoard.Windows.Rendering;

internal sealed class IncheonAirportAdapter(AirportProfile airport, StringCatalog strings)
    : ProfileAirportAdapter(airport, strings)
{
    public override void Header(Drawing drawing, Rect bounds, BoardFrame frame)
    {

        var height = HeaderHeight(bounds, frame.Settings.Scale);
        var unit = height / 230;
        var ink = Airport.Display.Text("headerInk", "ffffff");
        drawing.Fill(new Rect(0, 0, bounds.Width, height), Airport.Data.Text("header"));
        drawing.Border(new Rect(65 * unit, 28 * unit, 174 * unit, 178 * unit), "", ink, false);
        drawing.Plane(new Rect(90 * unit, 52 * unit, 124 * unit, 124 * unit), ink);
        drawing.Text(
            Strings.Get("heading.departures", "ko"),
            new Rect(290 * unit, 20 * unit, 230 * unit, height - 36 * unit),
            height * 0.47,
            ink,
            "Malgun Gothic",
            true
        );
        var asian =
            Strings.Get("heading.departures", "ja")
            + "  "
            + Strings.Get("heading.departures", "zh-Hans");
        drawing.Text(
            asian,
            new Rect(550 * unit, 16 * unit, 760 * unit, height * 0.43),
            height * 0.27,
            ink,
            bold: true
        );
        drawing.Fill(new Rect(550 * unit, height * 0.46, 490 * unit, 5 * unit), ink);
        drawing.Text(
            Strings.Get("heading.departures", "en"),
            new Rect(550 * unit, height * 0.48, 820 * unit, height * 0.37),
            height * 0.29,
            ink,
            bold: true
        );
    }

    public override void Footer(Drawing drawing, Rect bounds, BoardFrame frame, int page, int pages)
    {

        var height = Airport.Display.Number("footerHeight", 44);
        var y = bounds.Height - height;
        drawing.Fill(new Rect(0, y, bounds.Width, height), "080d13");
        drawing.Text(
            Airport.LocalTime(frame.Time).ToString("yyyy. MM. dd.", CultureInfo.InvariantCulture),
            new Rect(24, y + 2, 280, height - 4),
            height * 0.60,
            "ffffff",
            bold: true
        );
        drawing.Text(
            (page + 1).ToString(CultureInfo.InvariantCulture),
            new Rect(bounds.Width / 2 - 20, y + 2, 40, height - 4),
            height * 0.60,
            "ffffff",
            bold: true,
            alignment: TextAlignment.Center
        );
        drawing.Text(
            Airport.LocalTime(frame.Time).ToString("HH:mm", CultureInfo.InvariantCulture),
            new Rect(bounds.Width - 140, y + 2, 115, height - 4),
            height * 0.60,
            "ffea83",
            bold: true,
            alignment: TextAlignment.Right
        );
    }
}
