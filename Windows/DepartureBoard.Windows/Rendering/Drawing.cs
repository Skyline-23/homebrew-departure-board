using System;
using System.Collections.Generic;
using System.Globalization;
using System.Windows;
using System.Windows.Media;

namespace DepartureBoard.Windows.Rendering;

internal sealed class Drawing(DrawingContext context, TextLayoutCache? textLayouts = null)
{
    private static readonly Dictionary<string, SolidColorBrush> BrushesByColor = [];
    private static readonly Dictionary<(string Font, bool Bold), Typeface> Typefaces = [];

    public void Fill(Rect rectangle, string color)
    {

        if (rectangle.Width <= 0 || rectangle.Height <= 0)
        {
            return;
        }

        context.DrawRectangle(Brush(color), null, rectangle);
    }

    public void Text(
        string value,
        Rect rectangle,
        double size,
        string color,
        string font = "Segoe UI",
        bool bold = false,
        TextAlignment alignment = TextAlignment.Left
    )
    {

        if (value.Length == 0 || rectangle.Width <= 0 || rectangle.Height <= 0)
        {
            return;
        }

        var layoutKey = new TextLayoutCache.Key(
            value,
            rectangle.Size,
            size,
            color,
            font,
            bold,
            alignment,
            CultureInfo.CurrentUICulture.Name
        );
        FormattedText? formatted = null;
        textLayouts?.TryGet(layoutKey, out formatted);

        if (formatted is null)
        {
            var key = (font, bold);

            if (!Typefaces.TryGetValue(key, out var typeface))
            {
                typeface = CreateTypeface(font, bold);
                Typefaces[key] = typeface;
            }

            formatted = new FormattedText(
                value,
                CultureInfo.CurrentUICulture,
                FlowDirection.LeftToRight,
                typeface,
                Math.Max(6, size),
                Brush(color),
                1
            );
            var heightRatio = rectangle.Height / Math.Max(1, formatted.Height);
            var widthRatio =
                rectangle.Width / Math.Max(1, formatted.WidthIncludingTrailingWhitespace);
            var fit = Math.Min(1, Math.Min(heightRatio, Math.Max(0.65, widthRatio)));
            formatted.SetFontSize(Math.Max(1, size * fit));
            formatted.MaxTextWidth = rectangle.Width;
            formatted.MaxLineCount = 1;
            formatted.Trimming = TextTrimming.CharacterEllipsis;
            formatted.TextAlignment = alignment;
            textLayouts?.Add(layoutKey, formatted);
        }
        var y = rectangle.Y + Math.Max(0, (rectangle.Height - formatted.Height) / 2);
        context.PushClip(new RectangleGeometry(rectangle));
        context.DrawText(formatted, new Point(rectangle.X, y));
        context.Pop();
    }

    public void Image(ImageSource image, Rect rectangle)
    {

        var factor = Math.Min(rectangle.Width / image.Width, rectangle.Height / image.Height);
        var width = image.Width * factor;
        var height = image.Height * factor;
        context.DrawImage(
            image,
            new Rect(
                rectangle.X + (rectangle.Width - width) / 2,
                rectangle.Y + (rectangle.Height - height) / 2,
                width,
                height
            )
        );
    }

    public void Border(Rect rectangle, string fill, string stroke, bool circle)
    {

        var pen = new Pen(Brush(stroke), 2);
        var fillBrush = fill.Length == 0 ? null : Brush(fill);

        if (circle)
        {
            context.DrawEllipse(
                fillBrush,
                pen,
                new Point(rectangle.X + rectangle.Width / 2, rectangle.Y + rectangle.Height / 2),
                rectangle.Width / 2,
                rectangle.Height / 2
            );
        }
        else
        {
            context.DrawRoundedRectangle(fillBrush, pen, rectangle, 4, 4);
        }
    }

    public void Line(Point start, Point end, string color, double width)
    {

        context.DrawLine(new Pen(Brush(color), width), start, end);
    }

    public void Plane(Rect rectangle, string color)
    {

        Text("\uE709", rectangle, rectangle.Height * 0.8, color, "Segoe MDL2 Assets");
    }

    public static SolidColorBrush Brush(string color)
    {

        var key = color.StartsWith('#') ? color : "#" + color;

        if (!BrushesByColor.TryGetValue(key, out var brush))
        {
            brush = new SolidColorBrush((Color)ColorConverter.ConvertFromString(key));
            brush.Freeze();
            BrushesByColor[key] = brush;
        }

        return brush;
    }

    private static Typeface CreateTypeface(string font, bool bold)
    {

        var weight =
            bold || font.Contains("Bold", StringComparison.OrdinalIgnoreCase)
                ? FontWeights.SemiBold
                : FontWeights.Normal;
        var stretch = font.Contains("Condensed", StringComparison.OrdinalIgnoreCase)
            ? FontStretches.Condensed
            : FontStretches.Normal;
        return new Typeface(FontFamily(font), FontStyles.Normal, weight, stretch);
    }

    private static FontFamily FontFamily(string requested)
    {

        if (requested.StartsWith("Segoe", StringComparison.OrdinalIgnoreCase))
        {
            return new FontFamily(requested);
        }

        var name = requested switch
        {
            _ when requested.StartsWith("Menlo", StringComparison.OrdinalIgnoreCase) => "Consolas",
            _ when requested.Contains("Gothic", StringComparison.OrdinalIgnoreCase) =>
                "Malgun Gothic",
            _ when requested.Contains("Hiragino", StringComparison.OrdinalIgnoreCase) =>
                "Yu Gothic UI",
            _ when requested.Contains("Condensed", StringComparison.OrdinalIgnoreCase) =>
                "Bahnschrift SemiCondensed",
            _ when requested.StartsWith("Arial", StringComparison.OrdinalIgnoreCase) => "Arial",
            _ when requested.StartsWith("Helvetica", StringComparison.OrdinalIgnoreCase) => "Arial",
            _ => "Segoe UI",
        };
        return new FontFamily(name);
    }
}
