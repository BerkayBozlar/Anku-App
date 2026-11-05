
using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Security.Claims;
using AnkuApp.Api.Data;
using AnkuApp.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AnkuApp.Api.Controllers;

[ApiController]
[Route("api/clubs")]
[Authorize]
public class ClubsController : ControllerBase
{
    private const string AdminRole = "Yönetici";
    private const string ClubManagerRole = "Kulüp Yetkilisi";

    private static readonly CultureInfo TurkishCulture =
        CultureInfo.GetCultureInfo("tr-TR");

    private readonly AppDbContext _db;
    private readonly UserManager<ApplicationUser> _userManager;

    public ClubsController(
        AppDbContext db,
        UserManager<ApplicationUser> userManager)
    {
        _db = db;
        _userManager = userManager;
    }

    // mine=true: yalnızca giriş yapan kullanıcının yetkilisi olduğu kulüpler
    [HttpGet]
    public async Task<ActionResult<List<ClubResponse>>> GetAll(
        [FromQuery] bool mine = false)
    {
        var query = _db.Clubs
            .AsNoTracking()
            .Include(c => c.AuthorizedUser)
            .AsQueryable();

        if (mine)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            query = query.Where(c => c.AuthorizedUserId == userId);
        }

        var clubs = await query
            .OrderBy(c => c.Name)
            .ToListAsync();

        return clubs.Select(ToResponse).ToList();
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<ClubResponse>> GetById(int id)
    {
        var club = await _db.Clubs
            .AsNoTracking()
            .Include(c => c.AuthorizedUser)
            .FirstOrDefaultAsync(c => c.Id == id);

        if (club == null)
        {
            return NotFound();
        }

        return ToResponse(club);
    }

    [Authorize(Roles = AdminRole)]
    [HttpPost]
    public async Task<ActionResult<ClubResponse>> Create(
        [FromBody] ClubRequest request)
    {
        var club = new Club();
        await ApplyAsync(club, request, canChangeManager: true);

        if (!ModelState.IsValid)
        {
            return ValidationProblem(ModelState);
        }

        _db.Clubs.Add(club);
        await _db.SaveChangesAsync();

        return CreatedAtAction(
            nameof(GetById),
            new { id = club.Id },
            ToResponse(club));
    }

    // Kulüp yetkilisi yalnızca kendi kulübünü güncelleyebilir;
    // yetkili kullanıcıyı yalnızca yönetici değiştirir.
    [Authorize(Roles = AdminRole + "," + ClubManagerRole)]
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(
        int id,
        [FromBody] ClubRequest request)
    {
        var club = await _db.Clubs.FindAsync(id);

        if (club == null)
        {
            return NotFound();
        }

        var isAdmin = User.IsInRole(AdminRole);
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (!isAdmin && club.AuthorizedUserId != userId)
        {
            return Forbid();
        }

        await ApplyAsync(club, request, canChangeManager: isAdmin);

        if (!ModelState.IsValid)
        {
            return ValidationProblem(ModelState);
        }

        await _db.SaveChangesAsync();

        return NoContent();
    }

    [Authorize(Roles = AdminRole)]
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var club = await _db.Clubs.FindAsync(id);

        if (club == null)
        {
            return NotFound();
        }

        _db.Clubs.Remove(club);

        try
        {
            await _db.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            // Kulübe bağlı kayıtlar (ör. etkinlikler) varsa silinmez
            return Conflict(new
            {
                message = "Kulübe bağlı kayıtlar olduğu için silinemiyor."
            });
        }

        return NoContent();
    }

    private async Task ApplyAsync(
        Club club,
        ClubRequest request,
        bool canChangeManager)
    {
        var name = request.Name.Trim();

        // Büyük/küçük harf karşılaştırması veritabanının yerel ayarına
        // bırakılmaz; kulüp sayısı az olduğu için bellekte Türkçe kurallarla yapılır.
        var otherNames = await _db.Clubs
            .AsNoTracking()
            .Where(c => c.Id != club.Id)
            .Select(c => c.Name)
            .ToListAsync();

        var nameTaken = otherNames.Any(other => string.Compare(
            other,
            name,
            TurkishCulture,
            CompareOptions.IgnoreCase) == 0);

        if (nameTaken)
        {
            ModelState.AddModelError(
                nameof(ClubRequest.Name),
                "Bu adla bir kulüp zaten var.");
        }

        var socialMediaUrl = NullIfEmpty(request.SocialMediaUrl);

        if (socialMediaUrl != null && !IsHttpUrl(socialMediaUrl))
        {
            ModelState.AddModelError(
                nameof(ClubRequest.SocialMediaUrl),
                "Geçerli bir http veya https bağlantısı girin.");
        }

        club.Name = name;
        club.Description = NullIfEmpty(request.Description);
        club.SocialMediaUrl = socialMediaUrl;

        if (!canChangeManager)
        {
            return;
        }

        var email = NullIfEmpty(request.AuthorizedUserEmail);

        if (email == null)
        {
            club.AuthorizedUserId = null;
            club.AuthorizedUser = null;
            return;
        }

        if (!new EmailAddressAttribute().IsValid(email))
        {
            ModelState.AddModelError(
                nameof(ClubRequest.AuthorizedUserEmail),
                "Geçerli bir e-posta adresi girin.");
            return;
        }

        var user = await _userManager.FindByEmailAsync(email);

        if (user == null)
        {
            ModelState.AddModelError(
                nameof(ClubRequest.AuthorizedUserEmail),
                "Bu e-postayla kayıtlı kullanıcı yok.");
            return;
        }

        if (!await _userManager.IsInRoleAsync(user, ClubManagerRole))
        {
            ModelState.AddModelError(
                nameof(ClubRequest.AuthorizedUserEmail),
                "Kullanıcı Kulüp Yetkilisi rolünde değil.");
            return;
        }

        club.AuthorizedUserId = user.Id;
        club.AuthorizedUser = user;
    }

    // Yetkilinin e-postası yalnızca yöneticiye gösterilir
    private ClubResponse ToResponse(Club club) => new(
        club.Id,
        club.Name,
        club.Description,
        club.SocialMediaUrl,
        club.AuthorizedUser?.FullName,
        User.IsInRole(AdminRole) ? club.AuthorizedUser?.Email : null);

    private static string? NullIfEmpty(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    // javascript: gibi şemalar portalda bağlantı olarak gösterilmesin
    private static bool IsHttpUrl(string value) =>
        Uri.TryCreate(value, UriKind.Absolute, out var uri) &&
        (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps);
}

public record ClubResponse(
    int Id,
    string Name,
    string? Description,
    string? SocialMediaUrl,
    string? AuthorizedUserName,
    string? AuthorizedUserEmail);

public class ClubRequest
{
    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(2000)]
    public string? Description { get; set; }

    // Boş metin "alan yok" sayılır; biçim ApplyAsync içinde denetlenir
    [MaxLength(300)]
    public string? SocialMediaUrl { get; set; }

    public string? AuthorizedUserEmail { get; set; }
}
