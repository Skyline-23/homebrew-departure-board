using System.Collections.Generic;
using System.Windows;
using System.Windows.Media;

namespace DepartureBoard.Windows.Rendering;

internal sealed class TextLayoutCache
{
    internal readonly record struct Key(
        string Value,
        Size Bounds,
        double FontSize,
        string Color,
        string Font,
        bool Bold,
        TextAlignment Alignment,
        string Culture
    );

    private const int Capacity = 2048;
    private readonly Dictionary<Key, FormattedText> layouts = [];
    private readonly Queue<Key> insertionOrder = [];

    public bool TryGet(Key key, out FormattedText? layout)
    {

        return layouts.TryGetValue(key, out layout);
    }

    public void Add(Key key, FormattedText layout)
    {

        if (layouts.Count == Capacity)
        {
            layouts.Remove(insertionOrder.Dequeue());
        }

        layouts.Add(key, layout);
        insertionOrder.Enqueue(key);
    }
}
