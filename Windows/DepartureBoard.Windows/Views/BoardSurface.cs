using System;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;
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
    private readonly BoardDiagnostics diagnostics;
    private string? error;
    private int ticks;

    public BoardSurface(AppServices services)
    {

        this.services = services;
        diagnostics = new BoardDiagnostics(services.Diagnostics, "view");
        session = new BoardSession(services.Catalog, services.Flights);
        renderer = new BoardRenderer(services.Catalog);
        timer = new DispatcherTimer(DispatcherPriority.Background, Dispatcher)
        {
            Interval = TimeSpan.FromSeconds(1),
        };
        timer.Tick += OnTimerTick;
        Loaded += OnLoaded;
        Unloaded += OnUnloaded;
        IsVisibleChanged += (_, _) =>
        {
            if (IsVisible)
                Tick();
        };
    }

    public DateTimeOffset? ReferenceTime { get; set; }

    protected override void OnRender(DrawingContext drawingContext)
    {
        base.OnRender(drawingContext);

        if (session.Frame is { } frame && error is null)
        {
            renderer.Draw(drawingContext, RenderSize, frame);
            diagnostics.Presented(frame);
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
        services.DataChanged += OnDataChanged;
        services.Diagnostics.Write(new("view.started", services.Settings.Airport));
        timer.Start();
        Tick();
    }

    private void OnUnloaded(object sender, RoutedEventArgs arguments)
    {

        timer.Stop();
        services.SettingsChanged -= OnSettingsChanged;
        services.DataChanged -= OnDataChanged;
        services.Diagnostics.Write(new("view.stopped", services.Settings.Airport));
    }

    private void OnSettingsChanged(object? sender, EventArgs arguments)
    {

        Tick();
    }

    private void OnTimerTick(object? sender, EventArgs arguments)
    {

        if (IsVisible)
            Tick();
    }

    private void OnDataChanged(object? sender, EventArgs arguments)
    {

        if (IsVisible)
        {
            Tick();
        }
    }

    public void Tick()
    {

        try
        {
            error = null;

            if (
                session.Update(
                    services.Settings,
                    ReferenceTime ?? DateTimeOffset.UtcNow,
                    services.HasApiKey
                )
            )
            {
                if (
                    IsLoaded
                    && IsVisible
                    && services.Settings.Style == "flap"
                    && !services.Settings.ReduceMotion
                    && SystemParameters.ClientAreaAnimation
                )
                {
                    BeginAnimation(
                        OpacityProperty,
                        new DoubleAnimation(0.9, 1, TimeSpan.FromMilliseconds(140))
                    );
                }
                else
                {
                    BeginAnimation(OpacityProperty, null);
                }
                InvalidateVisual();
            }
        }
        catch (ArgumentException exception)
        {
            services.Diagnostics.Write(
                new("view.update_failed", services.Settings.Airport, exception.GetType().Name)
            );
            error = exception.Message;
            InvalidateVisual();
        }

        if (
            ReferenceTime is null
            && Window.GetWindow(this)?.WindowState != WindowState.Minimized
            && ticks++ % 30 == 0
        )
        {
            _ = services.RefreshAsync();
        }
    }
}
