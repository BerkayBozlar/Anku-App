
using System.ComponentModel.DataAnnotations;

namespace AnkuApp.Api.Contracts;

public class EventUpsertRequest
{
    [Range(1, int.MaxValue)]
    public int ClubId { get; set; }

    public int? CampusLocationId { get; set; }

    [Required]
    [MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    [MaxLength(2000)]
    public string? Description { get; set; }

    public DateTimeOffset EventDate { get; set; }

    [Range(1, int.MaxValue)]
    public int Capacity { get; set; }

    [Required]
    public string Status { get; set; } = "Draft";
}
