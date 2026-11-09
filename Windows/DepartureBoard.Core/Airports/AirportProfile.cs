using System.Text.Json;

namespace DepartureBoard.Core.Airports;

public sealed class AirportProfile
{
    public AirportProfile(JsonElement data)
    {

        if (data.Text("kind") != "airport")
        {
            throw new ArgumentException("Only airport profiles are supported.", nameof(data));
        }

        Data = data.Clone();
        Code = data.Text("code");
        TimeZone = TimeZoneInfo.FindSystemTimeZoneById(data.Text("zone"));
    }

    public JsonElement Data { get; }
    public JsonElement Display => Data.Child("display");
    public string Code { get; }
    public string Language => Data.Text("lang", "en");
    public string Name => Data.Text("name", Code);
    public string Adapter => Display.Text("adapter", "profile");
    public string[] Columns => Data.Strings("columns");
    public TimeZoneInfo TimeZone { get; }

    public DateTimeOffset LocalTime(DateTimeOffset timestamp)
    {
        return TimeZoneInfo.ConvertTime(timestamp, TimeZone);
    }
}
