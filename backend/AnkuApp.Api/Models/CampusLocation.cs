
namespace AnkuApp.Api.Models;

public class CampusLocation
{
    public int Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public string Campus { get; set; } = "Tandoğan";

    public string? Type { get; set; }

    public double? Latitude { get; set; }
    public double? Longitude { get; set; }

    public string? AccessibilityInfo { get; set; }

    public ICollection<Event> Events { get; set; }
        = new List<Event>();
}
