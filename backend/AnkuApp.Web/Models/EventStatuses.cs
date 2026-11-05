namespace AnkuApp.Web.Models;

/// <summary>API'deki etkinlik durumları ve portalda gösterilen adları.</summary>
public static class EventStatuses
{
    public const string Draft = "Draft";
    public const string Published = "Published";
    public const string Cancelled = "Cancelled";

    public static readonly string[] All = [Draft, Published, Cancelled];

    public static string DisplayName(string? status) => status switch
    {
        Draft => "Taslak",
        Published => "Yayında",
        Cancelled => "İptal edildi",
        _ => status ?? "-"
    };

    public static string BadgeClass(string? status) => status switch
    {
        Published => "text-bg-success",
        Cancelled => "text-bg-danger",
        _ => "text-bg-secondary"
    };
}
