
namespace AnkuApp.Api.Models;

public class Club
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? SocialMediaUrl { get; set; }

    public string? AuthorizedUserId { get; set; }
    public ApplicationUser? AuthorizedUser { get; set; }
    public ICollection<Event> Events { get; set; }
    = new List<Event>();
}
