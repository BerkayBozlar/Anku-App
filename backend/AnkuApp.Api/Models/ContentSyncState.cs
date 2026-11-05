namespace AnkuApp.Api.Models;

public class ContentSyncState
{
    public string Id { get; set; } = string.Empty;
    public DateTime? LastAttemptAt { get; set; }
    public DateTime? LastSuccessAt { get; set; }
    public string? LastError { get; set; }
}
