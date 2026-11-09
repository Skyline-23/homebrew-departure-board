using System;
using System.Globalization;
using System.Windows;
using DepartureBoard.Core.Airports;

namespace DepartureBoard.Windows.Rendering;

internal abstract class AirportAdapter(AirportProfile airport, StringCatalog strings)
{
    protected AirportProfile Airport { get; } = airport;
    protected StringCatalog Strings { get; } = strings;

    public virtual double HeaderHeight(Rect bounds, double scale)
    {

        var display = Airport.Display;
        var fraction = display.Number("headerFraction");
        var height =
            fraction > 0 ? bounds.Height * fraction * scale : display.Number("headerHeight");
        return Math.Max(height, display.Number("minimumHeaderHeight"));
    }

    public int RowCount(Rect bounds, BoardFrame frame)
    {

        if (frame.Settings.Density > 0)
        {
            return Math.Clamp(frame.Settings.Density, 8, 64);
        }

        var display = Airport.Display;
        var top = HeaderHeight(bounds, frame.Settings.Scale) + ColumnHeight + 4;
        var bottom = bounds.Height - Math.Max(29, display.Number("footerHeight") + 3);
        var minimum = display.Flag("stackedDestination") ? 49 : 34;
        var readable = (int)Math.Floor(Math.Max(0, bottom - top) / minimum);
        var preferred = (int)Math.Ceiling(display.Number("rowCount") / frame.Settings.Scale);
        return Math.Clamp(Math.Min(readable, preferred), 8, 64);
    }

    public double ColumnHeight =>
        Airport.Display.Strings("columnHeaderLanguages").Length > 1 ? 46 : 30;
    public abstract void Header(Drawing drawing, Rect bounds, BoardFrame frame);

    public virtual void Footer(Drawing drawing, Rect bounds, BoardFrame frame, int page, int pages)
    {

        var style = Airport.Display;
        var height = Math.Max(26, style.Number("footerHeight"));
        var area = new Rect(0, bounds.Height - height, bounds.Width, height);
        var ink = style.Text("footerInk", "ffffff");
        var mode = style.Text("footerStyle");
        drawing.Fill(area, style.Text("footerColor", "080d13"));

        if (mode == "date-clock")
        {
            drawing.Text(
                Airport.LocalTime(frame.Time).ToString("dd MMM yyyy", CultureInfo.InvariantCulture),
                new Rect(22, area.Y + 2, 370, height - 4),
                height * 0.6,
                ink
            );
        }

        if (mode == "pages")
        {
            drawing.Text(
                $"{page + 1} / {pages}",
                new Rect(22, area.Y + 2, 160, height - 4),
                height * 0.6,
                ink
            );
        }

        var notice = style.Text("footerNoticeKey");
        var message =
            notice.Length > 0 ? Strings.Get(notice, frame.Language) : style.Text("footerBrand");
        drawing.Text(
            message,
            new Rect(400, area.Y + 2, Math.Max(100, bounds.Width - 800), height - 4),
            height * 0.6,
            ink,
            alignment: TextAlignment.Center
        );

        if (mode.Length > 0 && mode != "brand-only")
        {
            drawing.Text(
                Airport.LocalTime(frame.Time).ToString("HH:mm", CultureInfo.InvariantCulture),
                new Rect(bounds.Width - 180, area.Y + 2, 158, height - 4),
                height * 0.6,
                ink,
                alignment: TextAlignment.Right
            );
        }
    }

    public static AirportAdapter Create(AirportProfile airport, StringCatalog strings)
    {

        return airport.Adapter switch
        {
            "profile" => new ProfileAirportAdapter(airport, strings),
            "incheon" => new IncheonAirportAdapter(airport, strings),
            "haneda" => new HanedaAirportAdapter(airport, strings),
            _ => throw new InvalidOperationException("Unknown airport adapter: " + airport.Adapter),
        };
    }
}
