using AnkuApp.Web.Auth;
using AnkuApp.Web.Models;
using AnkuApp.Web.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;

namespace AnkuApp.Web.Controllers;

/// <summary>
/// Etkinlik yönetimi. Yönetici tüm kulüplerin, kulüp yetkilisi yalnız kendi kulüplerinin
/// etkinliklerini görür; sahiplik kontrolünü ayrıca API yapar (403).
/// İşlem sayfaları <c>returnUrl</c> ile gelinen listeye (sekme, arama, kulüp, sayfa) döner.
/// </summary>
public class EventsController(EventsApiClient eventsApi, ClubsApiClient clubsApi) : PortalController
{
    private const int PageSize = 20;

    /// <param name="past">true: tarihi geçmiş etkinlikler (en yeni önce); false: yaklaşanlar (en yakın önce).</param>
    public async Task<IActionResult> Index(int pageNumber = 1, string? search = null, int? clubId = null, bool past = false, CancellationToken ct = default)
    {
        var clubs = await LoadClubsAsync(ct);
        if (clubs.Status == ApiStatus.Unauthorized)
        {
            return await ApiFailureAsync(clubs);
        }
        if (!clubs.IsSuccess)
        {
            return View(new EventListViewModel { Past = past, LoadError = clubs.Message ?? "Kulüpler yüklenemedi." });
        }

        var available = clubs.Value!;
        if (!IsAdmin)
        {
            if (available.Count == 0)
            {
                return View(new EventListViewModel
                {
                    Past = past,
                    LoadError = "Hesabınıza atanmış bir kulüp yok. Yöneticiden kulübünüzü size atamasını isteyin."
                });
            }

            // Kulüp yetkilisi her zaman kendi kulüplerinden birini görür
            if (clubId is null || available.All(c => c.Id != clubId))
            {
                clubId = available[0].Id;
            }
        }

        var now = DateTimeOffset.UtcNow;
        var query = new EventQuery(Math.Max(1, pageNumber), PageSize, search, clubId,
            From: past ? null : now,
            To: past ? now : null,
            Descending: past);
        var events = await eventsApi.ListAsync(query, ct);
        if (events.Status == ApiStatus.Unauthorized)
        {
            return await ApiFailureAsync(events);
        }

        // Son sayfadaki son etkinlik silindiyse boş sayfa yerine son dolu sayfa gösterilir
        if (events.Value is { Items.Count: 0, TotalCount: > 0 } page && query.Page > page.TotalPages)
        {
            return RedirectToAction(nameof(Index), new { pageNumber = page.TotalPages, search, clubId, past = past ? true : (bool?)null });
        }

        return View(new EventListViewModel
        {
            Page = events.Value,
            Search = search,
            ClubId = clubId,
            Past = past,
            Clubs = available,
            CanListAllClubs = IsAdmin,
            LoadError = events.IsSuccess ? null : events.Message ?? "Etkinlikler yüklenemedi."
        });
    }

    [HttpGet]
    public async Task<IActionResult> Create(int? clubId, string? returnUrl, CancellationToken ct)
    {
        var model = new EventFormViewModel { ClubId = clubId };
        return await FormViewAsync(model, returnUrl, ct);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(EventFormViewModel model, string? returnUrl, CancellationToken ct)
    {
        model.Id = null;
        if (!ModelState.IsValid)
        {
            return await FormViewAsync(model, returnUrl, ct);
        }

        var result = await eventsApi.CreateAsync(model.ToRequest(), ct);
        if (!result.IsSuccess)
        {
            return TryAddFormErrors<EventFormViewModel>(result) ? await FormViewAsync(model, returnUrl, ct) : await ApiFailureAsync(result);
        }

        SetStatusMessage($"\"{result.Value!.Title}\" etkinliği eklendi.");
        return RedirectToReturnUrl(returnUrl, () => RedirectToAction(nameof(Index), new { clubId = model.ClubId }));
    }

    /// <summary>Salt okunur ayrıntı; geçmiş etkinlikler buradan görüntülenir.</summary>
    [HttpGet]
    public async Task<IActionResult> Details(int id, string? returnUrl, CancellationToken ct)
    {
        var result = await eventsApi.GetAsync(id, ct);
        if (!result.IsSuccess)
        {
            return await ApiFailureAsync(result, "Etkinlik bulunamadı.");
        }

        SetReturnUrl(returnUrl);
        return View(result.Value);
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id, string? returnUrl, CancellationToken ct)
    {
        var result = await eventsApi.GetAsync(id, ct);
        if (!result.IsSuccess)
        {
            return await ApiFailureAsync(result, "Etkinlik bulunamadı.");
        }

        // API geçmiş tarihi kabul etmediği için geçmiş etkinlik kaydedilemez
        if (IsPast(result.Value!))
        {
            SetErrorMessage("Tarihi geçmiş etkinlikler düzenlenemez.");
            return RedirectToAction(nameof(Details), new { id, returnUrl = SafeReturnUrl(returnUrl) });
        }

        return await FormViewAsync(EventFormViewModel.From(result.Value!), returnUrl, ct);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, EventFormViewModel model, string? returnUrl, CancellationToken ct)
    {
        model.Id = id;
        if (!ModelState.IsValid)
        {
            return await FormViewAsync(model, returnUrl, ct);
        }

        var result = await eventsApi.UpdateAsync(id, model.ToRequest(), ct);
        if (!result.IsSuccess)
        {
            return TryAddFormErrors<EventFormViewModel>(result) ? await FormViewAsync(model, returnUrl, ct) : await ApiFailureAsync(result, "Etkinlik bulunamadı.");
        }

        SetStatusMessage("Etkinlik güncellendi.");
        return RedirectToReturnUrl(returnUrl, () => RedirectToAction(nameof(Index), new { clubId = model.ClubId }));
    }

    [HttpGet]
    public async Task<IActionResult> Delete(int id, string? returnUrl, CancellationToken ct)
    {
        var result = await eventsApi.GetAsync(id, ct);
        if (!result.IsSuccess)
        {
            return await ApiFailureAsync(result, "Etkinlik bulunamadı.");
        }

        SetReturnUrl(returnUrl);
        return View(result.Value);
    }

    [HttpPost, ActionName(nameof(Delete))]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(int id, int? clubId, bool past, string? returnUrl, CancellationToken ct)
    {
        IActionResult BackToList() =>
            RedirectToReturnUrl(returnUrl, () => RedirectToAction(nameof(Index), new { clubId, past = past ? true : (bool?)null }));

        var result = await eventsApi.DeleteAsync(id, ct);
        if (result.Status == ApiStatus.Conflict)
        {
            SetErrorMessage(result.Message ?? (past
                ? "Etkinliğe yapılmış başvurular olduğu için silinemiyor."
                : "Etkinliğe yapılmış başvurular olduğu için silinemiyor. Bunun yerine durumunu \"İptal edildi\" yapabilirsiniz."));
            return BackToList();
        }
        if (!result.IsSuccess)
        {
            return await ApiFailureAsync(result, "Etkinlik bulunamadı.");
        }

        SetStatusMessage("Etkinlik silindi.");
        return BackToList();
    }

    private bool IsAdmin => User.IsInRole(Roles.Yonetici);

    public static bool IsPast(EventDto e) => e.EventDate < DateTimeOffset.UtcNow;

    private Task<ApiResult<List<ClubDto>>> LoadClubsAsync(CancellationToken ct) =>
        clubsApi.ListAsync(mine: !IsAdmin, ct);

    /// <summary>Formu kulüp seçenekleriyle birlikte gösterir.</summary>
    private async Task<IActionResult> FormViewAsync(EventFormViewModel model, string? returnUrl, CancellationToken ct)
    {
        var clubs = await LoadClubsAsync(ct);
        if (clubs.Status == ApiStatus.Unauthorized)
        {
            return await ApiFailureAsync(clubs);
        }
        if (!clubs.IsSuccess)
        {
            ModelState.AddModelError(string.Empty, clubs.Message ?? "Kulüpler yüklenemedi.");
        }
        else if (clubs.Value!.Count == 0)
        {
            ModelState.AddModelError(string.Empty, IsAdmin
                ? "Önce bir kulüp ekleyin."
                : "Hesabınıza atanmış bir kulüp yok.");
        }

        var options = clubs.Value ?? [];
        if (model.ClubId is null && options.Count == 1)
        {
            model.ClubId = options[0].Id;
        }

        model.ClubOptions = options
            .Select(c => new SelectListItem(c.Name, c.Id.ToString()))
            .ToList();

        SetReturnUrl(returnUrl);
        return View("Form", model);
    }
}
