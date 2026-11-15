namespace AnkuApp.Api.Models;

public class AcademicCalendarEntry
{
    public int Id { get; set; }
    public string AcademicYear { get; set; } = "";
    public string Scope { get; set; } = "";
    public string Term { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Description { get; set; }
    public DateOnly StartDate { get; set; }
    public DateOnly EndDate { get; set; }
    public string SourceName { get; set; } = "";
    public string SourceUrl { get; set; } = "";
    public int? SourcePage { get; set; }
    public string UniqueKey { get; set; } = "";
    public DateTime RetrievedAt { get; set; }
    public bool IsManual { get; set; }
}
