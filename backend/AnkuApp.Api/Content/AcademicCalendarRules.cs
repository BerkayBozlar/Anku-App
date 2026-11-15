using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace AnkuApp.Api.Content;

public static class AcademicCalendarRules
{
    public const string GeneralScope = "Ön lisans ve lisans (genel takvim)";
    public static readonly string[] Terms = ["Fall", "Spring", "YearRound"];

    public static bool TryYear(string? value, out int startYear)
    {
        startYear = 0;
        return value is { Length: 9 } && Regex.IsMatch(value, @"^20\d{2}-\d{4}$") &&
            int.TryParse(value.AsSpan(0, 4), out startYear) &&
            int.TryParse(value.AsSpan(5, 4), out var endYear) && endYear == startYear + 1;
    }

    public static string CurrentYear(DateTimeOffset now)
    {
        var date = ContentSources.TurkeyDate(now);
        var year = date.Month >= 8 ? date.Year : date.Year - 1;
        return $"{year}-{year + 1}";
    }

    public static string Normalize(string text) => Regex.Replace(text, @"\s+", " ").Trim();
    public static string Key(string year, string scope, string term, string title, string discriminator) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(string.Join('|', year, scope, term, Normalize(title), discriminator))));

    // Resmî takvimdeki tek gün, aynı ay, farklı ay ve yıl geçişli tarih aralıkları.
    public static (DateOnly Start, DateOnly End) ParseDates(string text)
    {
        var parts = Normalize(text).Replace('–', '-').Replace('—', '-').Split('-');
        if (parts.Length is < 1 or > 2) throw new InvalidDataException("Takvim tarih aralığı çözümlenemedi.");
        (int Day, int? Month, int? Year) Part(string value)
        {
            var match = Regex.Match(value.Trim(), @"^(?<day>\d{1,2})(?:\s+(?<month>\p{L}+))?(?:\s+(?<year>\d{4}))?$", RegexOptions.None, TimeSpan.FromSeconds(1));
            if (!match.Success) throw new InvalidDataException("Takvim tarihi çözümlenemedi.");
            int? month = null;
            if (match.Groups["month"].Success)
            {
                var months = CultureInfo.GetCultureInfo("tr-TR").DateTimeFormat.MonthNames;
                var index = Array.FindIndex(months, m => string.Compare(m, match.Groups["month"].Value, true, CultureInfo.GetCultureInfo("tr-TR")) == 0);
                if (index < 0) throw new InvalidDataException("Takvimde bilinmeyen ay adı.");
                month = index + 1;
            }
            return (int.Parse(match.Groups["day"].Value, CultureInfo.InvariantCulture), month,
                match.Groups["year"].Success ? int.Parse(match.Groups["year"].Value, CultureInfo.InvariantCulture) : null);
        }
        var first = Part(parts[0]);
        var last = Part(parts[^1]);
        if (last.Month is null || last.Year is null) throw new InvalidDataException("Takvim tarihinin ay/yıl bilgisi eksik.");
        var startMonth = first.Month ?? last.Month.Value;
        var startYear = first.Year ?? last.Year.Value - (startMonth > last.Month.Value ? 1 : 0);
        try
        {
            var start = new DateOnly(startYear, startMonth, first.Day);
            var end = new DateOnly(last.Year.Value, last.Month.Value, last.Day);
            if (end < start) throw new InvalidDataException("Takvim başlangıcı bitişten sonra.");
            return (start, end);
        }
        catch (ArgumentOutOfRangeException ex) { throw new InvalidDataException("Takvimde geçersiz gün/ay/yıl.", ex); }
    }
}
