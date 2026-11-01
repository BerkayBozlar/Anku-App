namespace AnkuApp.Web.Auth;

/// <summary>
/// API'nin döndürdüğü rol adları (docs/api-sozlesmesi.md).
/// </summary>
public static class Roles
{
    public const string Yonetici = "Yonetici";
    public const string KulupYetkilisi = "KulupYetkilisi";
    public const string Ogrenci = "Ogrenci";

    /// <summary>Portala giriş yapabilen roller.</summary>
    public const string PortalRoles = Yonetici + "," + KulupYetkilisi;

    public static bool CanUsePortal(string? role) =>
        role is Yonetici or KulupYetkilisi;

    public static string DisplayName(string? role) => role switch
    {
        Yonetici => "Yönetici",
        KulupYetkilisi => "Kulüp Yetkilisi",
        Ogrenci => "Öğrenci",
        _ => "Bilinmeyen rol"
    };
}
