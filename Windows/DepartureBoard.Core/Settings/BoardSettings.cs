namespace DepartureBoard.Core.Settings;

public sealed record BoardSettings
{
    public string Airport { get; init; } = "ICN";
    public string Language { get; init; } = "alternate";
    public string Style { get; init; } = "auto";
    public bool SampleData { get; init; } = true;
    public double Scale { get; init; } = 0.75;
    public double Brightness { get; init; } = 1;
    public bool ReduceMotion { get; init; }
    public bool ShowAllDesktops { get; init; } = true;
    public int Density { get; init; }
    public int RefreshSeconds { get; init; } = 300;
    public bool WallpaperEnabled { get; init; }
    public bool LaunchAtLogin { get; init; }

    public BoardSettings Normalize()
    {
        return this with
        {
            Language = Language is "english" or "native" ? Language : "alternate",
            Style = Style is "flap" or "lcd" ? Style : "auto",
            Scale = double.IsFinite(Scale) ? Math.Clamp(Scale, 0.5, 1) : 0.75,
            Brightness = double.IsFinite(Brightness) ? Math.Clamp(Brightness, 0.35, 1) : 1,
            Density = Density == 0 ? 0 : Math.Clamp(Density, 8, 64),
            RefreshSeconds = Math.Clamp(RefreshSeconds, 60, 21600),
        };
    }
}
