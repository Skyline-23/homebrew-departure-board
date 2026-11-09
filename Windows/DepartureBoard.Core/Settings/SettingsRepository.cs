using System.Text.Json;

namespace DepartureBoard.Core.Settings;

public sealed class SettingsRepository(string directory)
{
    private readonly string path = Path.Combine(directory, "settings.json");
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true };

    public BoardSettings Load()
    {

        try
        {
            return File.Exists(path)
                ? JsonSerializer.Deserialize<BoardSettings>(File.ReadAllText(path)) ?? new()
                : new();
        }
        catch (JsonException)
        {
            return new();
        }
    }

    public void Save(BoardSettings settings)
    {

        Directory.CreateDirectory(directory);
        var temporaryPath = path + ".new";
        File.WriteAllText(temporaryPath, JsonSerializer.Serialize(settings, Options));
        File.Move(temporaryPath, path, true);
    }
}
