using System;
using System.Collections.Generic;
using DepartureBoard.Core.Airports;
using DepartureBoard.Core.Flights;
using DepartureBoard.Core.Settings;

namespace DepartureBoard.Windows.Rendering;

internal sealed record BoardFrame(
    AirportProfile Airport,
    IReadOnlyList<BoardRow> Rows,
    DateTimeOffset Time,
    string Language,
    BoardSettings Settings,
    int PageCycle,
    string EmptyMessage
);
