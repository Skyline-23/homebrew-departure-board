using DepartureBoard.Core.Diagnostics;

namespace DepartureBoard.Windows.Rendering;

internal sealed class BoardDiagnostics(IDiagnosticSink diagnostics, string surface)
{
    private string? previous;

    public void Presented(BoardFrame frame)
    {

        var state = frame.Rows.Count > 0 ? "ready" : frame.EmptyMessage;
        var key = $"{frame.Airport.Code}:{frame.Settings.SampleData}:{state}";

        if (key == previous)
        {
            return;
        }

        previous = key;
        diagnostics.Write(
            new(surface + ".frame_presented", frame.Airport.Code, state, Count: frame.Rows.Count)
        );
    }
}
