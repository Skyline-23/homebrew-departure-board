using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using DepartureBoard.Windows.Rendering;
using Microsoft.Win32;

namespace DepartureBoard.Windows.Platform;

internal static class WallpaperSnapshot
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SystemParametersInfo(
        uint action,
        uint parameter,
        string value,
        uint flags
    );

    public static void Apply(AppServices services)
    {

        var bounds = System.Windows.Forms.SystemInformation.VirtualScreen;
        var renderer = new BoardRenderer(services.Catalog);
        var session = new BoardSession(services.Catalog, services.Flights);
        session.Update(services.Settings, DateTimeOffset.UtcNow, services.HasApiKey);
        var visual = new DrawingVisual();
        using (var drawing = visual.RenderOpen())
        {
            foreach (var screen in System.Windows.Forms.Screen.AllScreens)
            {
                drawing.PushTransform(
                    new TranslateTransform(screen.Bounds.X - bounds.X, screen.Bounds.Y - bounds.Y)
                );
                renderer.Draw(
                    drawing,
                    new Size(screen.Bounds.Width, screen.Bounds.Height),
                    session.Frame!
                );
                drawing.Pop();
            }
        }
        var bitmap = new RenderTargetBitmap(
            bounds.Width,
            bounds.Height,
            96,
            96,
            PixelFormats.Pbgra32
        );
        bitmap.Render(visual);
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        var folder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "DepartureBoard"
        );
        Directory.CreateDirectory(folder);
        var path = Path.Combine(folder, "Wallpaper.png");
        using (var stream = File.Create(path))
        {
            encoder.Save(stream);
        }
        using var desktop = Registry.CurrentUser.CreateSubKey(@"Control Panel\Desktop");
        desktop.SetValue("WallpaperStyle", "22");
        desktop.SetValue("TileWallpaper", "0");

        if (!SystemParametersInfo(20, 0, path, 3))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
    }
}
