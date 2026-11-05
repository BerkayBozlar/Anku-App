using System.ComponentModel.DataAnnotations;
using AnkuApp.Web.Services;

namespace AnkuApp.Web.Models;

public class ClubListViewModel
{
    public List<ClubDto> Clubs { get; init; } = [];

    /// <summary>API'ye ulaşılamadıysa liste yerine gösterilir.</summary>
    public string? LoadError { get; init; }
}

public class ClubFormViewModel
{
    public int? Id { get; set; }

    [Required(ErrorMessage = "Kulüp adı zorunludur.")]
    [StringLength(100, ErrorMessage = "Kulüp adı en fazla 100 karakter olabilir.")]
    [Display(Name = "Kulüp adı")]
    public string Name { get; set; } = string.Empty;

    [StringLength(2000, ErrorMessage = "Açıklama en fazla 2000 karakter olabilir.")]
    [Display(Name = "Açıklama")]
    public string? Description { get; set; }

    [Url(ErrorMessage = "Geçerli bir bağlantı girin (https://...).")]
    [StringLength(300, ErrorMessage = "Bağlantı en fazla 300 karakter olabilir.")]
    [Display(Name = "Sosyal medya bağlantısı")]
    public string? SocialMediaUrl { get; set; }

    [EmailAddress(ErrorMessage = "Geçerli bir e-posta adresi girin.")]
    [Display(Name = "Kulüp yetkilisinin e-postası")]
    public string? AuthorizedUserEmail { get; set; }

    /// <summary>Yetkili kullanıcıyı yalnızca yönetici değiştirebilir.</summary>
    public bool CanChangeManager { get; set; }

    public bool IsNew => Id is null;

    public static ClubFormViewModel From(ClubDto club, bool canChangeManager) => new()
    {
        Id = club.Id,
        Name = club.Name,
        Description = club.Description,
        SocialMediaUrl = club.SocialMediaUrl,
        AuthorizedUserEmail = club.AuthorizedUserEmail,
        CanChangeManager = canChangeManager
    };

    public ClubRequest ToRequest() => new(
        Name.Trim(),
        Description?.Trim(),
        SocialMediaUrl?.Trim(),
        CanChangeManager ? AuthorizedUserEmail?.Trim() : null);
}
