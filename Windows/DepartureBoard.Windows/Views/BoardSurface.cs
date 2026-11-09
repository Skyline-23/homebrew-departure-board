using System;
using System.Windows;
using System.Windows.Media;
using System.Windows.Threading;
using DepartureBoard.Windows.Rendering;
using BoardDrawing = DepartureBoard.Windows.Rendering.Drawing;

namespace DepartureBoard.Windows.Views;

internal sealed class BoardSurface : FrameworkElement
{
    private readonly AppServices services;
    private readonly BoardSession session;
    private readonly BoardRenderer renderer;
    private readonly DispatcherTimer timer;
    private string? error;
    private int ticks;

    public BoardSurface(AppServices services)
    {

        this.services = services;
        session = new BoardSession(services.Catalog, services.Flights);
        renderer = new BoardRenderer(services.Catalog);
        timer = new DispatcherTimer(DispatcherPriority.Background, Dispatcher)
        {
            Interval = TimeSpan.FromSeconds(1),
        };
        timer.Tick += OnTimerTick;
        Loaded += OnLoaded;
        Unloaded += OnUnloaded;
    }

    public DateTimeOffset? ReferenceTime { get; set; }

    protected override void OnRender(DrawingContext drawingContext)
    {
        base.OnRender(drawingContext);

        if (session.Frame is { } frame && error is null)
        {
            renderer.Draw(drawingContext, RenderSize, frame);
        }
        else
        {
            var drawing = new BoardDrawing(drawingContext);
            drawing.Fill(new Rect(RenderSize), "080d13");
            drawing.Text(
                error ?? "Select an airport in Settings.",
                new Rect(30, 30, Math.Max(1, ActualWidth - 60), Math.Max(1, ActualHeight - 60)),
                24,
                "ffffff"
            );
        }
    }

    private void OnLoaded(object sender, RoutedEventArgs arguments)
    {

        services.SettingsChanged += OnSettingsChanged;
        timer.Start();
        Tick();
    }

    private void OnUnloaded(object sender, RoutedEventArgs arguments)
    {

        timer.Stop();
        services.SettingsChanged -= OnSettingsChanged;
    }

    private void OnSettingsChanged(object? sender, EventArgs arguments)
    {

        Tick();
    }

    private void OnTimerTick(object? sender, EventArgs arguments)
    {

        Tick();
    }

    public void Tick()
    {

        try
        {
            error = null;

            if (session.Update(services.Settings, ReferenceTime ?? DateTimeOffset.UtcNow))
            {
                InvalidateVisual();
            }
        }
        catch (ArgumentException exception)
        {
            error = exception.Message;
            InvalidateVisual();
        }

        if (ReferenceTime is null && ticks++ % 30 == 0)
        {
            _ = services.RefreshAsync();
        }
    }
}
