using AnkuApp.Web.Auth;
using AnkuApp.Web.Models;
using AnkuApp.Web.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;

namespace AnkuApp.Web.Controllers;

/// <summary>
/// Etkinlik yönetimi. Yönetici tüm kulüplerin, kulüp yetkilisi yalnız kendi kulüplerinin
/// etkinliklerini görür; sahiplik kontrolünü ayrıca API yapar (403).
/// </summary>
public class EventsController(EventsApiClient eventsApi, ClubsApiClient clubsApi) : PortalController
{
    private const int PageSize = 20;

    public async Task<IActionResult> Index(int pageNumber = 1, string? search = null, int? clubId = null, CancellationToken ct = default)
    {
        var clubs = await LoadClubsAsync(ct);
        if (clubs.Status == ApiStatus.Unauthorized)
        {
            return await ApiFailureAsync(clubs);
        }
        if (!clubs.IsSuccess)
        {
            return View(new EventListViewModel { LoadError = clubs.Message ?? "Kulüpler yüklenemedi." });
        }

        var available = clubs.Value!;
        if (!IsAdmin)
        {
            if (available.Count == 0)
            {
                return View(new EventListViewModel
                {
                    LoadError = "Hesabınıza atanmış bir kulüp yok. Yöneticiden kulübünüzü size atamasını isteyin."
                });
            }

            // Kulüp yetkilisi her zaman kendi kulüplerinden birini görür
            if (clubId is null || available.All(c => c.Id != clubId))
            {
                clubId = available[0].Id;
            }
        }

        var query = new EventQuery(Math.Max(1, pageNumber), PageSize, search, clubId);
        var events = await eventsApi.ListAsync(query, ct);
        if (events.Status == ApiStatus.Unauthorized)
        {
            return await ApiFailureAsync(events);
        }

        return View(new EventListViewModel
        {
            Page = events.Value,
            Search = search,
            ClubId = clubId,
            Clubs = available,
            CanListAllClubs = IsAdmin,
            LoadError = events.IsSuccess ? null : events.Message ?? "Etkinlikler yüklenemedi."
        });
    }

    [HttpGet]
    public async Task<IActionResult> Create(int? clubId, CancellationToken ct)
    {
        var model = new EventFormViewModel { ClubId = clubId };
        return await FormViewAsync(model, ct);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(EventFormViewModel model, CancellationToken ct)
    {
        model.Id = null;
        if (!ModelState.IsValid)
        {
            return await FormViewAsync(model, ct);
        }

        var result = await eventsApi.CreateAsync(model.ToRequest(), ct);
        if (!result.IsSuccess)
        {
            return TryAddFormErrors<EventFormViewModel>(result) ? await FormViewAsync(model, ct) : await ApiFailureAsync(result);
        }

        SetStatusMessage($"\"{result.Value!.Title}\" etkinliği eklendi.");
        return RedirectToAction(nameof(Index), new { clubId = model.ClubId });
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id, CancellationToken ct)
    {
        var result = await eventsApi.GetAsync(id, ct);
        if (!result.IsSuccess)
        {
            return await ApiFailureAsync(result, "Etkinlik bulunamadı.");
        }

        return await FormViewAsync(EventFormViewModel.From(result.Value!), ct);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, EventFormViewModel model, CancellationToken ct)
    {
        model.Id = id;
        if (!ModelState.IsValid)
        {
            return await FormViewAsync(model, ct);
        }

        var result = await eventsApi.UpdateAsync(id, model.ToRequest(), ct);
        if (!result.IsSuccess)
        {
            return TryAddFormErrors<EventFormViewModel>(result) ? await FormViewAsync(model, ct) : await ApiFailureAsync(result, "Etkinlik bulunamadı.");
        }

        SetStatusMessage("Etkinlik güncellendi.");
        return RedirectToAction(nameof(Index), new { clubId = model.ClubId });
    }

    [HttpGet]
    public async Task<IActionResult> Delete(int id, CancellationToken ct)
    {
        var result = await eventsApi.GetAsync(id, ct);
        if (!result.IsSuccess)
        {
            return await ApiFailureAsync(result, "Etkinlik bulunamadı.");
        }

        return View(result.Value);
    }

    [HttpPost, ActionName(nameof(Delete))]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(int id, int? clubId, CancellationToken ct)
    {
        var result = await eventsApi.DeleteAsync(id, ct);
        if (result.Status == ApiStatus.Conflict)
        {
            SetErrorMessage(result.Message ?? "Etkinliğe yapılmış başvurular olduğu için silinemiyor. Bunun yerine durumunu \"İptal edildi\" yapabilirsiniz.");
            return RedirectToAction(nameof(Index), new { clubId });
        }
        if (!result.IsSuccess)
        {
            return await ApiFailureAsync(result, "Etkinlik bulunamadı.");
        }

        SetStatusMessage("Etkinlik silindi.");
        return RedirectToAction(nameof(Index), new { clubId });
    }

    private bool IsAdmin => User.IsInRole(Roles.Yonetici);

    private Task<ApiResult<List<ClubDto>>> LoadClubsAsync(CancellationToken ct) =>
        clubsApi.ListAsync(mine: !IsAdmin, ct);

    /// <summary>Formu kulüp seçenekleriyle birlikte gösterir.</summary>
    private async Task<IActionResult> FormViewAsync(EventFormViewModel model, CancellationToken ct)
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

        return View("Form", model);
    }
}
