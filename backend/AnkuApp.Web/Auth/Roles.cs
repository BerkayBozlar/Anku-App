using System.Globalization;
using System.Text;

namespace AnkuApp.Web.Auth;

/// <summary>
/// Portal içinde kullanılan rol adları. API rolleri "Yönetici", "Kulüp Yetkilisi"
/// gibi Türkçe karakterli ya da "Yonetici" gibi sade yazımla dönebilir;
/// <see cref="Normalize"/> ikisini de bu sabitlere çevirir.
/// </summary>
public static class Roles
{
    public const string Yonetici = "Yonetici";
    public const string KulupYetkilisi = "KulupYetkilisi";
    public const string Ogrenci = "Ogrenci";

    /// <summary>Yetkisi en yüksekten en düşüğe.</summary>
    private static readonly string[] ByPriority = [Yonetici, KulupYetkilisi, Ogrenci];

    public static bool CanUsePortal(string? role) =>
        role is Yonetici or KulupYetkilisi;

    public static string DisplayName(string? role) => role switch
    {
        Yonetici => "Yönetici",
        KulupYetkilisi => "Kulüp Yetkilisi",
        Ogrenci => "Öğrenci",
        _ => "Bilinmeyen rol"
    };

    /// <summary>API'den gelen rol adını portal sabitine çevirir; tanınmazsa null.</summary>
    public static string? Normalize(string? apiRole)
    {
        if (string.IsNullOrWhiteSpace(apiRole))
        {
            return null;
        }

        var key = Simplify(apiRole);
        return ByPriority.FirstOrDefault(role => Simplify(role) == key);
    }

    /// <summary>Kullanıcının birden çok rolü varsa en yetkili olanı seçer.</summary>
    public static string? Primary(IEnumerable<string?> apiRoles)
    {
        var known = apiRoles.Select(Normalize).ToHashSet();
        return ByPriority.FirstOrDefault(known.Contains);
    }

    // "Kulüp Yetkilisi" -> "kulupyetkilisi"
    private static string Simplify(string value)
    {
        var builder = new StringBuilder(value.Length);
        foreach (var c in value.Normalize(NormalizationForm.FormD))
        {
            if (char.IsWhiteSpace(c) || CharUnicodeInfo.GetUnicodeCategory(c) == UnicodeCategory.NonSpacingMark)
            {
                continue;
            }

            builder.Append(c == 'ı' ? 'i' : char.ToLowerInvariant(c));
        }

        return builder.ToString();
    }
}
