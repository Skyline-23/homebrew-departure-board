using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Windows.Media.Imaging;
using DepartureBoard.Core.Airports;
using DepartureBoard.Core.Flights;

namespace DepartureBoard.Windows.Rendering;

internal sealed class LogoStore(string resourceDirectory)
{
    private readonly Dictionary<string, BitmapImage?> cache = [];
    private readonly Queue<string> order = [];
    private readonly JsonElement catalog = ReadCatalog(resourceDirectory);

    public BitmapImage? Get(BoardRow row)
    {

        var carrier =
            row.Flight.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? "";
        var code = row.Icao;

        if (code.Length == 0)
        {
            var candidates = catalog.Child(carrier);
            code =
                candidates.ValueKind == JsonValueKind.Array && candidates.GetArrayLength() > 0
                    ? candidates[0].Text("icao")
                    : carrier;
        }

        if (cache.TryGetValue(code, out var existing))
        {
            return existing;
        }

        var path = Path.Combine(resourceDirectory, "AirlineLogos", code + ".png");
        BitmapImage? image = null;

        if (File.Exists(path))
        {
            image = new BitmapImage();
            image.BeginInit();
            image.CacheOption = BitmapCacheOption.OnLoad;
            image.DecodePixelWidth = 256;
            image.UriSource = new Uri(path);
            image.EndInit();
            image.Freeze();
        }

        cache[code] = image;
        order.Enqueue(code);

        while (order.Count > 128)
        {
            cache.Remove(order.Dequeue());
        }

        return image;
    }

    private static JsonElement ReadCatalog(string resources)
    {

        using var document = JsonDocument.Parse(
            File.ReadAllText(Path.Combine(resources, "AirlineLogos", "Catalog.json"))
        );
        return document.RootElement.Clone();
    }
}
