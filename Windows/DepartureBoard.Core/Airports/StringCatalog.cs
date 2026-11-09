using System.Text.RegularExpressions;

namespace DepartureBoard.Core.Airports;

public sealed partial class StringCatalog
{
    private readonly Dictionary<string, Dictionary<string, string>> tables = [];

    public StringCatalog(string resourceDirectory)
    {

        foreach (var directory in Directory.EnumerateDirectories(resourceDirectory, "*.lproj"))
        {
            var language = Path.GetFileName(directory)
                .Replace(".lproj", "", StringComparison.Ordinal);
            var table = new Dictionary<string, string>();
            var text = File.ReadAllText(Path.Combine(directory, "Localizable.strings"));

            foreach (Match match in StringEntry().Matches(text))
            {
                table[match.Groups[1].Value] = Regex.Unescape(match.Groups[2].Value);
            }

            tables[language] = table;
        }
    }

    public string Get(string key, string language = "en")
    {

        if (tables.TryGetValue(language, out var table) && table.TryGetValue(key, out var value))
        {
            return value;
        }

        return
            tables.TryGetValue("en", out var english) && english.TryGetValue(key, out var fallback)
            ? fallback
            : key;
    }

    [GeneratedRegex(
        "^\\\"([^\\\"]+)\\\"\\s*=\\s*\\\"((?:\\\\.|[^\\\"])*)\\\";",
        RegexOptions.Multiline
    )]
    private static partial Regex StringEntry();
}
