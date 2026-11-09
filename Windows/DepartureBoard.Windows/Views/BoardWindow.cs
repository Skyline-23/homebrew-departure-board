using System;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;

namespace DepartureBoard.Windows.Views;

internal sealed class BoardWindow : Window
{
    private readonly DateTime shownAt = DateTime.UtcNow;
    private Point? firstMousePosition;

    public BoardWindow(AppServices services, bool screenSaver)
    {

        Title = "Departure Board";
        Content = new BoardSurface(services);
        Background = Brushes.Black;
        WindowStyle = screenSaver ? WindowStyle.None : WindowStyle.SingleBorderWindow;
        ResizeMode = screenSaver ? ResizeMode.NoResize : ResizeMode.CanResize;
        ShowInTaskbar = !screenSaver;
        Topmost = screenSaver;
        Width = 1280;
        Height = 720;

        if (screenSaver)
        {
            Cursor = Cursors.None;
            KeyDown += (_, _) => Application.Current.Shutdown();
            MouseDown += (_, _) => Application.Current.Shutdown();
            MouseMove += OnMouseMove;
        }
    }

    private void OnMouseMove(object sender, MouseEventArgs arguments)
    {

        var point = arguments.GetPosition(this);
        firstMousePosition ??= point;

        if (
            DateTime.UtcNow - shownAt > TimeSpan.FromSeconds(1)
            && (point - firstMousePosition.Value).Length > 4
        )
        {
            Application.Current.Shutdown();
        }
    }
}
