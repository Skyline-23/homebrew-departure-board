namespace DepartureBoard.Core.Runtime;

public enum LaunchMode
{
    Settings,
    ScreenSaver,
    Preview,
    Background,
    SelfTest,
    Guide,
}

public sealed record LaunchOptions(LaunchMode Mode, nint PreviewParent = default)
{
    public static LaunchOptions Parse(string[] arguments)
    {

        if (arguments.Length == 0)
        {
            return new(LaunchMode.Settings);
        }
        var parts = arguments[0].Split(':', 2);
        var option = parts[0].ToLowerInvariant();

        if (option == "/p")
        {
            var value = parts.Length > 1 ? parts[1] : arguments.ElementAtOrDefault(1);

            if (!long.TryParse(value, out var handle) || handle <= 0)
            {
                throw new ArgumentException("Preview mode requires a parent window handle.");
            }

            return new(LaunchMode.Preview, (nint)handle);
        }

        return option switch
        {
            "/s" => new(LaunchMode.ScreenSaver),
            "/c" => new(LaunchMode.Settings),
            "--background" => new(LaunchMode.Background),
            "--self-test" => new(LaunchMode.SelfTest),
            "--guide" => new(LaunchMode.Guide),
            _ => throw new ArgumentException("Unknown launch option."),
        };
    }
}
