using System.Drawing;

namespace DepartureBoard.Windows.Platform;

internal static class DesktopGeometry
{
    public static Rectangle ContentBounds(Rectangle screen, Rectangle workingArea)
    {

        var visible = Rectangle.Intersect(screen, workingArea);
        const int margin = 16;
        return new Rectangle(
            visible.X - screen.X + margin,
            visible.Y - screen.Y + margin,
            System.Math.Max(1, visible.Width - 2 * margin),
            System.Math.Max(1, visible.Height - 2 * margin)
        );
    }
}
