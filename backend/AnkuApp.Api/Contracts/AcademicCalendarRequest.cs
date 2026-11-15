using System.ComponentModel.DataAnnotations;
using AnkuApp.Api.Content;

namespace AnkuApp.Api.Contracts;

public sealed class AcademicCalendarRequest : IValidatableObject
{
    [Required] public string AcademicYear { get; set; } = "";
    [Required, MaxLength(200)] public string Scope { get; set; } = AcademicCalendarRules.GeneralScope;
    [Required] public string Term { get; set; } = "Fall";
    [Required, MaxLength(400)] public string Title { get; set; } = "";
    [MaxLength(2000)] public string? Description { get; set; }
    [Required] public DateOnly? StartDate { get; set; }
    [Required] public DateOnly? EndDate { get; set; }
    [Required, MaxLength(150)] public string SourceName { get; set; } = "Ankara Üniversitesi Öğrenci İşleri";
    [Required, OfficialSourceUrl] public string SourceUrl { get; set; } = "";
    [Range(1, 50)] public int? SourcePage { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (!AcademicCalendarRules.TryYear(AcademicYear, out var year))
            yield return new("Akademik yıl ardışık iki yıldan oluşmalıdır (ör. 2026-2027).", [nameof(AcademicYear)]);
        else if ((StartDate is { } start && (start.Year < year || start.Year > year + 1)) ||
                 (EndDate is { } end && (end.Year < year || end.Year > year + 1)))
            yield return new("Tarihler belirtilen akademik yılın iki takvim yılı içinde olmalıdır.", [nameof(StartDate), nameof(EndDate)]);
        if (StartDate > EndDate)
            yield return new("Bitiş tarihi başlangıçtan önce olamaz.", [nameof(EndDate)]);
        if (!AcademicCalendarRules.Terms.Contains(Term))
            yield return new("Dönem Fall, Spring veya YearRound olmalıdır.", [nameof(Term)]);
    }
}
