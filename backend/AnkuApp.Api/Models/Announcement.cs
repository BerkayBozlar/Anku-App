namespace AnkuApp.Api.Models;

public class Announcement
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Summary { get; set; }
    public string SourceName { get; set; } = string.Empty;
    public string SourceUrl { get; set; } = string.Empty;
    public string UniqueKey { get; set; } = string.Empty;
    public DateTime PublishedAt { get; set; }
    public DateTime RetrievedAt { get; set; }
    public bool IsManual { get; set; }
}
