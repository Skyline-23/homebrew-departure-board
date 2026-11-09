using System;
using System.Globalization;
using System.Windows;
using DepartureBoard.Core.Airports;

namespace DepartureBoard.Windows.Rendering;

internal class ProfileAirportAdapter(AirportProfile airport, StringCatalog strings)
    : AirportAdapter(airport, strings)
{
    public override void Header(Drawing drawing, Rect bounds, BoardFrame frame)
    {

        var style = Airport.Display;
        var height = HeaderHeight(bounds, frame.Settings.Scale);
        var ink = style.Text("headerInk", "ffffff");
        var clockStyle = style.Text("clockStyle", "plain");
        var clockWidth = ClockWidth(height);
        drawing.Fill(new Rect(0, 0, bounds.Width, height), Airport.Data.Text("header"));
        var left = DrawIcon(drawing, height, ink);
        left = DrawBrand(drawing, frame, left, height, ink);
        var titleArea = new Rect(
            left,
            0,
            Math.Max(100, bounds.Width - clockWidth - left - 46),
            height
        );
        DrawTitle(drawing, frame, titleArea, ink);

        if (clockWidth > 0)
        {
            var clock = new Rect(
                bounds.Width - clockWidth - 22,
                height * 0.10,
                clockWidth,
                height * 0.8
            );
            DrawClock(drawing, clock, frame, clockStyle, style.Text("clockColor", ink));
        }

        var rule = style.Text("headerRule");

        if (rule.Length > 0)
        {
            drawing.Fill(new Rect(0, height - 2, bounds.Width, 2), rule);
        }
    }

    private double ClockWidth(double height)
    {

        if (Airport.Display.Text("clockPosition") == "footer")
        {
            return 0;
        }

        return Airport.Display.Text("clockStyle") == "analog"
            ? height
            : 188 * Math.Min(1.4, height / 100);
    }

    private double DrawIcon(Drawing drawing, double height, string ink)
    {

        var style = Airport.Display;
        var icon = style.Text("headerIcon", "plane");

        if (icon == "none")
        {
            return 22;
        }

        var size = Math.Min(60, height * 0.56);
        var rectangle = new Rect(22, (height - size) / 2, size, size);

        if (icon is "boxed" or "circle")
        {
            drawing.Border(rectangle, style.Text("iconFill"), ink, icon == "circle");
        }

        drawing.Plane(rectangle, style.Text("iconInk", ink));
        return 22 + size + 18;
    }

    private double DrawBrand(
        Drawing drawing,
        BoardFrame frame,
        double left,
        double height,
        string ink
    )
    {

        var style = Airport.Display;
        var brand = style.Text("brand");
        var terminal = SingleTerminal(frame);

        if (style.Flag("terminalHeading") && terminal.Length > 0)
        {
            brand = Strings.Get("column.terminal", frame.Language) + " " + terminal;
        }

        if (brand.Length == 0)
        {
            return left;
        }

        var width = style.Number("brandWidth", 170);
        var lines = brand.Split('\n');
        var lineHeight = (height - 16) / lines.Length;

        for (var index = 0; index < lines.Length; index++)
        {
            var area = new Rect(left, 8 + index * lineHeight, width, lineHeight);
            drawing.Text(
                lines[index],
                area,
                Math.Min(30, height * 0.28),
                ink,
                style.Text("headerFont")
            );
        }

        return left + width + 24;
    }

    private void DrawTitle(Drawing drawing, BoardFrame frame, Rect area, string ink)
    {

        var style = Airport.Display;
        var layout = style.Text("headerLayout", "stacked");
        var languages = style.Strings("headerLanguages");
        var primaryLanguage = languages.Length > 0 ? languages[0] : frame.Language;
        var secondaryLanguage =
            languages.Length > 1 ? languages[1]
            : frame.Language == "en" ? Airport.Language
            : "en";
        var titleKey = style.Text("titleKey", Airport.Data.Text("titleKey"));
        var primary = Strings.Get(titleKey, primaryLanguage);
        var secondary = Strings.Get(titleKey, secondaryLanguage);
        var bilingual = primary != secondary && layout != "single";
        var size = Math.Min(
            style.Number("titleSize", 60),
            area.Height * (bilingual && layout == "stacked" ? 0.40 : 0.57)
        );
        var alignment = layout == "centered" ? TextAlignment.Center : TextAlignment.Left;
        var font = style.Text("headerFont");

        if (bilingual && layout == "stacked")
        {
            var top = new Rect(area.X, area.Height * 0.08, area.Width, area.Height * 0.47);
            var bottom = new Rect(area.X, area.Height * 0.54, area.Width, area.Height * 0.36);
            drawing.Text(primary, top, size, ink, font, true, alignment);
            drawing.Text(
                secondary,
                bottom,
                size * 0.75,
                style.Text("headerSecondaryInk", ink),
                font,
                true,
                alignment
            );
            return;
        }

        var title = bilingual && layout == "inline" ? primary + "   " + secondary : primary;
        drawing.Text(title, area, size, ink, font, true, alignment);
    }

    private static string SingleTerminal(BoardFrame frame)
    {

        var terminal = "";

        foreach (var row in frame.Rows)
        {
            if (row.Terminal.Length == 0)
            {
                continue;
            }

            if (terminal.Length > 0 && terminal != row.Terminal)
            {
                return "";
            }

            terminal = row.Terminal;
        }

        return terminal;
    }

    private void DrawClock(Drawing drawing, Rect bounds, BoardFrame frame, string style, string ink)
    {

        var time = Airport.LocalTime(frame.Time);

        if (style == "analog")
        {
            DrawAnalogClock(drawing, bounds, time);
            return;
        }

        if (style == "digital")
        {
            drawing.Fill(bounds, "11171b");
        }

        drawing.Text(
            time.ToString("HH:mm", CultureInfo.InvariantCulture),
            bounds,
            Math.Min(56, bounds.Height * 0.78),
            ink,
            bold: true,
            alignment: TextAlignment.Right
        );
    }

    private static void DrawAnalogClock(Drawing drawing, Rect bounds, DateTimeOffset time)
    {

        var diameter = Math.Min(bounds.Width, bounds.Height);
        var center = new Point(bounds.X + bounds.Width / 2, bounds.Y + bounds.Height / 2);
        var face = new Rect(center.X - diameter / 2, center.Y - diameter / 2, diameter, diameter);
        drawing.Border(face, "ffffff", "354044", true);

        for (var tick = 0; tick < 12; tick++)
        {
            var angle = tick * Math.PI / 6 - Math.PI / 2;
            drawing.Line(
                Polar(center, angle, diameter * 0.37),
                Polar(center, angle, diameter * 0.44),
                "354044",
                2
            );
        }

        var hourAngle = (time.Hour % 12 + time.Minute / 60.0) * Math.PI / 6 - Math.PI / 2;
        var minuteAngle = time.Minute * Math.PI / 30 - Math.PI / 2;
        drawing.Line(center, Polar(center, hourAngle, diameter * 0.25), "354044", 3);
        drawing.Line(center, Polar(center, minuteAngle, diameter * 0.36), "354044", 2);
    }

    private static Point Polar(Point center, double angle, double radius)
    {

        return new Point(center.X + Math.Cos(angle) * radius, center.Y + Math.Sin(angle) * radius);
    }
}
