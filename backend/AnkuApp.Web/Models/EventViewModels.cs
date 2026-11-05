using System.ComponentModel.DataAnnotations;
using AnkuApp.Web.Services;
using Microsoft.AspNetCore.Mvc.Rendering;

namespace AnkuApp.Web.Models;

public class EventListViewModel
{
    public EventPage? Page { get; init; }

    public string? Search { get; init; }

    public int? ClubId { get; init; }

    /// <summary>Filtrede seçilebilen kulüpler; kulüp yetkilisi için yalnız kendi kulüpleri.</summary>
    public List<ClubDto> Clubs { get; init; } = [];

    /// <summary>Yönetici "tüm kulüpler"i seçebilir; kulüp yetkilisi bir kulüp seçmek zorundadır.</summary>
    public bool CanListAllClubs { get; init; }

    public string? LoadError { get; init; }
}

public class EventFormViewModel : IValidatableObject
{
    public int? Id { get; set; }

    [Required(ErrorMessage = "Kulüp seçin.")]
    [Display(Name = "Kulüp")]
    public int? ClubId { get; set; }

    /// <summary>Konum seçimi kampüs konumları API'si gelince eklenecek; şimdilik mevcut değer korunur.</summary>
    public int? CampusLocationId { get; set; }

    [Required(ErrorMessage = "Başlık zorunludur.")]
    [StringLength(200, ErrorMessage = "Başlık en fazla 200 karakter olabilir.")]
    [Display(Name = "Başlık")]
    public string Title { get; set; } = string.Empty;

    [StringLength(2000, ErrorMessage = "Açıklama en fazla 2000 karakter olabilir.")]
    [Display(Name = "Açıklama")]
    public string? Description { get; set; }

    [Required(ErrorMessage = "Tarih ve saat zorunludur.")]
    [DataType(DataType.DateTime)]
    [Display(Name = "Tarih ve saat")]
    public DateTime? EventDate { get; set; }

    [Required(ErrorMessage = "Kontenjan zorunludur.")]
    [Range(1, 100_000, ErrorMessage = "Kontenjan 1 ile 100.000 arasında olmalıdır.")]
    [Display(Name = "Kontenjan")]
    public int? Capacity { get; set; }

    [Required(ErrorMessage = "Durum seçin.")]
    [Display(Name = "Durum")]
    public string Status { get; set; } = EventStatuses.Published;

    public List<SelectListItem> ClubOptions { get; set; } = [];

    public bool IsNew => Id is null;

    public static EventFormViewModel From(EventDto e) => new()
    {
        Id = e.Id,
        ClubId = e.ClubId,
        CampusLocationId = e.CampusLocationId,
        Title = e.Title,
        Description = e.Description,
        EventDate = PortalTime.ToLocal(e.EventDate),
        Capacity = e.Capacity,
        Status = e.Status
    };

    public EventRequest ToRequest() => new(
        ClubId!.Value,
        CampusLocationId,
        Title.Trim(),
        string.IsNullOrWhiteSpace(Description) ? null : Description.Trim(),
        PortalTime.ToUtc(EventDate!.Value),
        Capacity!.Value,
        Status);

    // API ile aynı kurallar (docs/api-sozlesmesi.md); API yine de son sözü söyler
    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (EventDate is DateTime date && date < PortalTime.Now)
        {
            yield return new ValidationResult("Etkinlik tarihi geçmişte olamaz.", [nameof(EventDate)]);
        }

        if (!EventStatuses.All.Contains(Status))
        {
            yield return new ValidationResult("Geçersiz durum.", [nameof(Status)]);
        }
    }
}
