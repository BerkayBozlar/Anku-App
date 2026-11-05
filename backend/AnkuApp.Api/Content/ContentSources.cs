using System.Security.Cryptography;
using System.Text;

namespace AnkuApp.Api.Content;

public sealed class ContentSourceOptions
{
    public bool Enabled { get; set; } = true;
    public string AnnouncementsUrl { get; set; } = "https://oidb.ankara.edu.tr/category/duyurular/feed/";
    public string MealMenusUrl { get; set; } = "https://sksbasvuru.ankara.edu.tr/kayit/moduller/yemeklistesi/aylikmenu.php";
}

public static class ContentSources
{
    private static readonly TimeZoneInfo Turkey = FindTurkey();

    public static DateOnly TurkeyDate(DateTimeOffset instant) => DateOnly.FromDateTime(
        TimeZoneInfo.ConvertTime(instant, Turkey).DateTime);

    private static TimeZoneInfo FindTurkey()
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Europe/Istanbul");
        }
        catch (Exception ex) when (ex is TimeZoneNotFoundException or InvalidTimeZoneException)
        {
            // Saat dilimi verisi olmayan ortamlar (ör. tzdata'sız konteyner). Türkiye 2016'dan beri sabit UTC+3.
            return TimeZoneInfo.CreateCustomTimeZone("Turkey", TimeSpan.FromHours(3), "Türkiye", "Türkiye");
        }
    }

    public static bool IsOfficialUrl(string? value) =>
        Uri.TryCreate(value, UriKind.Absolute, out var uri) &&
        uri.Scheme is "https" or "http" && string.IsNullOrEmpty(uri.UserInfo) && uri.IsDefaultPort &&
        (uri.Host.Equals("ankara.edu.tr", StringComparison.OrdinalIgnoreCase) ||
         uri.Host.EndsWith(".ankara.edu.tr", StringComparison.OrdinalIgnoreCase)) && value.Length <= 2000;

    public static string NormalizeUrl(string value)
    {
        var uri = new UriBuilder(value.Trim()) { Fragment = "" };
        uri.Path = uri.Path.TrimEnd('/');
        return uri.Uri.AbsoluteUri;
    }

    public static string UniqueKey(string url) => Convert.ToHexString(
        SHA256.HashData(Encoding.UTF8.GetBytes(NormalizeUrl(url))));
}
