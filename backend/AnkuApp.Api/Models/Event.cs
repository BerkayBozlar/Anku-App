
namespace AnkuApp.Api.Models;

public enum EventStatus
{
    Draft,
    Published,
    Cancelled
}

public class Event
{
    public int Id { get; set; }

    public int ClubId { get; set; }
    public Club Club { get; set; } = null!;

    public int? CampusLocationId { get; set; }
    public CampusLocation? CampusLocation { get; set; }

    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }

    public DateTime EventDate { get; set; }

    public int Capacity { get; set; }

    public EventStatus Status { get; set; } = EventStatus.Draft;
}
