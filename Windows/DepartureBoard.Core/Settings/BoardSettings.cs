namespace DepartureBoard.Core.Settings;

public sealed record BoardSettings
{
    public string Airport { get; init; } = "ICN";
    public string Language { get; init; } = "alternate";
    public string Style { get; init; } = "auto";
    public bool SampleData { get; init; } = true;
    public double Scale { get; init; } = 0.75;
    public int Density { get; init; }
    public int RefreshSeconds { get; init; } = 300;
    public bool WallpaperEnabled { get; init; }
    public bool LaunchAtLogin { get; init; }
}
