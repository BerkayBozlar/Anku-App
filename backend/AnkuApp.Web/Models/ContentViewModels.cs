using System.ComponentModel.DataAnnotations;
using AnkuApp.Web.Services;

namespace AnkuApp.Web.Models;

public class AnnouncementListViewModel
{
    public AnnouncementPage? Page { get; init; }
    public string? Search { get; init; }
    public string? LoadError { get; init; }
    public ContentSyncDto? Sync { get; init; }
}

public class AnnouncementFormViewModel
{
    public int? Id { get; set; }
    [Required(ErrorMessage = "Başlık zorunludur."), StringLength(300), Display(Name = "Başlık")]
    public string Title { get; set; } = "";
    [StringLength(4000), Display(Name = "Özet")]
    public string? Summary { get; set; }
    [Required, StringLength(150), Display(Name = "Kaynak adı")]
    public string SourceName { get; set; } = "Ankara Üniversitesi Öğrenci İşleri";
    [Required(ErrorMessage = "Resmî kaynak bağlantısı zorunludur."), StringLength(2000), Display(Name = "Kaynak bağlantısı")]
    public string SourceUrl { get; set; } = "";
    [Required, DataType(DataType.DateTime), Display(Name = "Yayın tarihi (Türkiye saati)")]
    public DateTime? PublishedAt { get; set; } = PortalTime.Now;

    public AnnouncementRequest ToRequest() => new(Title.Trim(), Summary?.Trim(), SourceName.Trim(), SourceUrl.Trim(), PortalTime.ToUtc(PublishedAt!.Value));
    public static AnnouncementFormViewModel From(AnnouncementDto dto) => new()
    {
        Id = dto.Id, Title = dto.Title, Summary = dto.Summary, SourceName = dto.SourceName,
        SourceUrl = dto.SourceUrl, PublishedAt = PortalTime.ToLocal(dto.PublishedAt)
    };
}

public class MealMenuListViewModel
{
    public List<MealMenuDto> Items { get; init; } = [];
    public DateOnly Date { get; init; }
    public string? LoadError { get; init; }
    public ContentSyncDto? Sync { get; init; }
}

public class MealMenuFormViewModel : IValidatableObject
{
    public int? Id { get; set; }
    [Required, DataType(DataType.Date), Display(Name = "Menü tarihi")]
    public DateOnly? MenuDate { get; set; } = DateOnly.FromDateTime(PortalTime.Now);
    [Required(ErrorMessage = "Her satıra bir yemek girin."), StringLength(2500), Display(Name = "Yemekler (her satıra bir yemek)")]
    public string DishesText { get; set; } = "";
    [Range(1, 20000), Display(Name = "Toplam enerji (kkal, isteğe bağlı)")]
    public int? TotalCalories { get; set; }
    [Required, StringLength(150), Display(Name = "Kaynak adı")]
    public string SourceName { get; set; } = "Ankara Üniversitesi SKS";
    [Required, StringLength(2000), Display(Name = "Kaynak bağlantısı")]
    public string SourceUrl { get; set; } = "https://sks.ankara.edu.tr/yemek-hizmetleri-2/";

    private string[] Dishes => DishesText.Split('\n', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
    public MealMenuRequest ToRequest() => new(MenuDate!.Value, Dishes, TotalCalories, SourceName.Trim(), SourceUrl.Trim());
    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Dishes.Length is < 1 or > 8 || Dishes.Any(d => d.Length > 300))
            yield return new("1–8 yemek girin; her yemek en fazla 300 karakter olabilir.", [nameof(DishesText)]);
    }
    public static MealMenuFormViewModel From(MealMenuDto dto) => new()
    {
        Id = dto.Id, MenuDate = dto.MenuDate, DishesText = string.Join(Environment.NewLine, dto.Dishes),
        TotalCalories = dto.TotalCalories, SourceName = dto.SourceName, SourceUrl = dto.SourceUrl
    };
}
