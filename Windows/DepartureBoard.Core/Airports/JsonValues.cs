using System.Text.Json;

namespace DepartureBoard.Core.Airports;

public static class JsonValues
{
    public static JsonElement Child(this JsonElement element, string name)
    {

        return
            element.ValueKind == JsonValueKind.Object && element.TryGetProperty(name, out var value)
            ? value
            : default;
    }

    public static string Text(this JsonElement element, string name, string fallback = "")
    {

        var value = element.Child(name);
        return value.ValueKind == JsonValueKind.String ? value.GetString() ?? fallback : fallback;
    }

    public static double Number(this JsonElement element, string name, double fallback = 0)
    {

        return element.Child(name).TryNumber(out var number) ? number : fallback;
    }

    public static bool Flag(this JsonElement element, string name)
    {

        return element.Child(name).ValueKind == JsonValueKind.True;
    }

    public static string[] Strings(this JsonElement element, string name)
    {

        var value = element.Child(name);
        return value.ValueKind == JsonValueKind.Array
            ? value.EnumerateArray().Select(item => item.GetString() ?? "").ToArray()
            : [];
    }

    private static bool TryNumber(this JsonElement element, out double number)
    {

        number = 0;
        return element.ValueKind == JsonValueKind.Number && element.TryGetDouble(out number);
    }
}
