namespace AnkuApp.Web.Services;

/// <summary>
/// API tarihleri UTC tutar; portal formları ve listeleri Türkiye saatiyle çalışır.
/// </summary>
public static class PortalTime
{
    private static readonly TimeZoneInfo Turkey = FindTurkey();

    public static DateTime Now => TimeZoneInfo.ConvertTime(DateTime.UtcNow, Turkey);

    public static DateTime ToLocal(DateTimeOffset value) =>
        TimeZoneInfo.ConvertTime(value, Turkey).DateTime;

    /// <summary>Formdan gelen Türkiye saatini UTC'ye çevirir.</summary>
    public static DateTime ToUtc(DateTime local) =>
        TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(local, DateTimeKind.Unspecified), Turkey);

    public static string Format(DateTimeOffset value) =>
        ToLocal(value).ToString("dd.MM.yyyy HH:mm");

    private static TimeZoneInfo FindTurkey()
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Europe/Istanbul");
        }
        catch (TimeZoneNotFoundException)
        {
            // Türkiye 2016'dan beri yaz saati uygulamıyor, sabit UTC+3
            return TimeZoneInfo.CreateCustomTimeZone("Turkey", TimeSpan.FromHours(3), "Türkiye", "Türkiye");
        }
    }
}
