using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using DepartureBoard.Windows.Rendering;
using Forms = System.Windows.Forms;

namespace DepartureBoard.Windows.Platform;

// A native child presents WPF's pixels. WPF's top-level HWND compositor is not
// supported beneath the layered DefView used by newer Windows 11 desktops.
internal sealed class WallpaperWindow : Forms.Form
{
    private readonly AppServices services;
    private readonly BoardSession session;
    private readonly BoardRenderer renderer;
    private readonly DispatcherTimer timer;
    private readonly nint host;
    private readonly nint after;
    private readonly Rectangle bounds;
    private readonly Rectangle contentBounds;
    private readonly bool layered;
    private Bitmap? pixels;
    private RenderTargetBitmap? target;

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetLayeredWindowAttributes(
        nint window,
        uint color,
        byte alpha,
        uint flags
    );

    public WallpaperWindow(
        AppServices services,
        nint host,
        nint after,
        Rectangle bounds,
        bool layered,
        Rectangle contentBounds
    )
    {

        this.services = services;
        this.host = host;
        this.after = after;
        this.bounds = bounds;
        this.contentBounds = contentBounds;
        this.layered = layered;
        session = new BoardSession(services.Catalog, services.Flights);
        renderer = new BoardRenderer(services.Catalog);
        FormBorderStyle = Forms.FormBorderStyle.None;
        ShowInTaskbar = false;
        TopLevel = false;
        SetStyle(
            Forms.ControlStyles.UserPaint
                | Forms.ControlStyles.AllPaintingInWmPaint
                | Forms.ControlStyles.OptimizedDoubleBuffer
                | Forms.ControlStyles.Opaque,
            true
        );
        timer = new DispatcherTimer(
            TimeSpan.FromSeconds(1),
            DispatcherPriority.Background,
            (_, _) => UpdateBoard(),
            System.Windows.Application.Current.Dispatcher
        );
        services.SettingsChanged += OnSettingsChanged;
    }

    protected override Forms.CreateParams CreateParams
    {
        get
        {
            var parameters = base.CreateParams;
            parameters.Parent = host;
            parameters.X = bounds.X;
            parameters.Y = bounds.Y;
            parameters.Width = bounds.Width;
            parameters.Height = bounds.Height;
            parameters.Style = (parameters.Style | 0x40000000) & unchecked((int)~0x80000000);
            parameters.ExStyle |= 0x08000000 | 0x80 | 0x20;

            if (layered)
            {
                parameters.ExStyle |= 0x80000;
            }
            return parameters;
        }
    }

    protected override void OnHandleCreated(EventArgs arguments)
    {

        base.OnHandleCreated(arguments);
        WindowEmbedding.Attach(
            Handle,
            host,
            bounds.X,
            bounds.Y,
            bounds.Width,
            bounds.Height,
            after
        );

        if (layered && !SetLayeredWindowAttributes(Handle, 0, 255, 2))
        {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }
    }

    protected override void OnVisibleChanged(EventArgs arguments)
    {

        base.OnVisibleChanged(arguments);

        if (Visible)
        {
            UpdateBoard();
        }
    }

    private void OnSettingsChanged(object? sender, EventArgs arguments)
    {

        UpdateBoard();
    }

    private void UpdateBoard()
    {

        if (
            !Visible
            || IsDisposed
            || !session.Update(services.Settings, DateTimeOffset.UtcNow, services.HasApiKey)
        )
        {
            return;
        }

        var width = bounds.Width;
        var height = bounds.Height;
        pixels ??= new Bitmap(width, height, System.Drawing.Imaging.PixelFormat.Format32bppPArgb);
        target ??= new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
        var visual = new DrawingVisual();
        using (var drawing = visual.RenderOpen())
        {
            drawing.DrawRectangle(
                Rendering.Drawing.Brush("030508"),
                null,
                new System.Windows.Rect(0, 0, width, height)
            );
            drawing.PushTransform(new TranslateTransform(contentBounds.X, contentBounds.Y));
            renderer.Draw(
                drawing,
                new System.Windows.Size(contentBounds.Width, contentBounds.Height),
                session.Frame!
            );
            drawing.Pop();
        }
        target.Clear();
        target.Render(visual);
        var data = pixels.LockBits(
            new Rectangle(0, 0, width, height),
            ImageLockMode.WriteOnly,
            System.Drawing.Imaging.PixelFormat.Format32bppPArgb
        );

        try
        {
            target.CopyPixels(
                new System.Windows.Int32Rect(0, 0, width, height),
                data.Scan0,
                data.Stride * height,
                data.Stride
            );
        }
        finally
        {
            pixels.UnlockBits(data);
        }
        Invalidate();
    }

    protected override void OnPaint(Forms.PaintEventArgs arguments)
    {

        if (pixels is not null)
        {
            arguments.Graphics.DrawImageUnscaled(pixels, 0, 0);
        }
    }

    protected override void Dispose(bool disposing)
    {

        if (disposing)
        {
            timer.Stop();
            services.SettingsChanged -= OnSettingsChanged;
            pixels?.Dispose();
        }
        base.Dispose(disposing);
    }
}
