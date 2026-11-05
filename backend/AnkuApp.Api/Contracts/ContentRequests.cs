using System.ComponentModel.DataAnnotations;
using AnkuApp.Api.Content;

namespace AnkuApp.Api.Contracts;

public sealed class OfficialSourceUrlAttribute : ValidationAttribute
{
    public OfficialSourceUrlAttribute() => ErrorMessage = "Ankara Üniversitesi alanında geçerli bir http/https kaynak bağlantısı girin.";
    public override bool IsValid(object? value) => value is string url && ContentSources.IsOfficialUrl(url);
}

public sealed class AnnouncementRequest : IValidatableObject
{
    [Required, MaxLength(300)] public string Title { get; set; } = "";
    [MaxLength(4000)] public string? Summary { get; set; }
    [Required, MaxLength(150)] public string SourceName { get; set; } = "";
    [Required, OfficialSourceUrl] public string SourceUrl { get; set; } = "";
    [Required] public DateTimeOffset? PublishedAt { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (PublishedAt is { Year: < 2000 or > 2100 })
            yield return new("Yayın tarihi 2000–2100 arasında olmalıdır.", [nameof(PublishedAt)]);
    }
}

public sealed class MealMenuRequest : IValidatableObject
{
    [Required] public DateOnly? MenuDate { get; set; }
    [Required, MinLength(1), MaxLength(8)] public string[] Dishes { get; set; } = [];
    [Range(1, 20000)] public int? TotalCalories { get; set; }
    [Required, MaxLength(150)] public string SourceName { get; set; } = "Ankara Üniversitesi SKS";
    [Required, OfficialSourceUrl] public string SourceUrl { get; set; } = "";

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (MenuDate is { Year: < 2000 or > 2100 })
            yield return new("Menü tarihi 2000–2100 arasında olmalıdır.", [nameof(MenuDate)]);
        if (Dishes is not null && Dishes.Any(d => string.IsNullOrWhiteSpace(d) || d.Length > 300))
            yield return new("Her yemek adı 1–300 karakter olmalıdır.", [nameof(Dishes)]);
    }
}
