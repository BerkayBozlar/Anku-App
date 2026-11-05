using AnkuApp.Web.Auth;
using AnkuApp.Web.Models;
using AnkuApp.Web.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AnkuApp.Web.Controllers;

/// <summary>
/// Yönetici tüm kulüpleri yönetir; kulüp yetkilisi yalnız kendi kulübünün bilgilerini düzenler.
/// </summary>
public class ClubsController(ClubsApiClient clubsApi) : PortalController
{
    [Authorize(Roles = Roles.Yonetici)]
    public async Task<IActionResult> Index(CancellationToken ct)
    {
        var result = await clubsApi.ListAsync(ct: ct);
        if (result.Status == ApiStatus.Unauthorized)
        {
            return await ApiFailureAsync(result);
        }

        return View(new ClubListViewModel
        {
            Clubs = result.Value ?? [],
            LoadError = result.IsSuccess ? null : result.Message ?? "Kulüpler yüklenemedi."
        });
    }

    [Authorize(Roles = Roles.KulupYetkilisi)]
    public async Task<IActionResult> Mine(CancellationToken ct)
    {
        var result = await clubsApi.ListAsync(mine: true, ct);
        if (result.Status == ApiStatus.Unauthorized)
        {
            return await ApiFailureAsync(result);
        }

        return View(new ClubListViewModel
        {
            Clubs = result.Value ?? [],
            LoadError = result.IsSuccess ? null : result.Message ?? "Kulüp bilgileri yüklenemedi."
        });
    }

    [Authorize(Roles = Roles.Yonetici)]
    [HttpGet]
    public IActionResult Create() => View("Form", new ClubFormViewModel { CanChangeManager = true });

    [Authorize(Roles = Roles.Yonetici)]
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(ClubFormViewModel model, CancellationToken ct)
    {
        model.Id = null;
        model.CanChangeManager = true;
        if (!ModelState.IsValid)
        {
            return View("Form", model);
        }

        var result = await clubsApi.CreateAsync(model.ToRequest(), ct);
        if (!result.IsSuccess)
        {
            return TryAddFormErrors<ClubFormViewModel>(result) ? View("Form", model) : await ApiFailureAsync(result);
        }

        SetStatusMessage($"\"{result.Value!.Name}\" kulübü eklendi.");
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id, CancellationToken ct)
    {
        var result = await clubsApi.GetAsync(id, ct);
        if (!result.IsSuccess)
        {
            return await ApiFailureAsync(result, "Kulüp bulunamadı.");
        }

        return View("Form", ClubFormViewModel.From(result.Value!, IsAdmin));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, ClubFormViewModel model, CancellationToken ct)
    {
        model.Id = id;
        model.CanChangeManager = IsAdmin;
        if (!ModelState.IsValid)
        {
            return View("Form", model);
        }

        // Kulüp yetkilisi başka bir kulübü düzenlemeye çalışırsa API 403 döner
        var result = await clubsApi.UpdateAsync(id, model.ToRequest(), ct);
        if (!result.IsSuccess)
        {
            return TryAddFormErrors<ClubFormViewModel>(result) ? View("Form", model) : await ApiFailureAsync(result, "Kulüp bulunamadı.");
        }

        SetStatusMessage("Kulüp bilgileri güncellendi.");
        return RedirectToAction(ListAction);
    }

    [Authorize(Roles = Roles.Yonetici)]
    [HttpGet]
    public async Task<IActionResult> Delete(int id, CancellationToken ct)
    {
        var result = await clubsApi.GetAsync(id, ct);
        if (!result.IsSuccess)
        {
            return await ApiFailureAsync(result, "Kulüp bulunamadı.");
        }

        return View(result.Value);
    }

    [Authorize(Roles = Roles.Yonetici)]
    [HttpPost, ActionName(nameof(Delete))]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(int id, CancellationToken ct)
    {
        var result = await clubsApi.DeleteAsync(id, ct);
        if (result.Status == ApiStatus.Conflict)
        {
            SetErrorMessage(result.Message ?? "Kulübe bağlı etkinlikler olduğu için silinemiyor.");
            return RedirectToAction(nameof(Index));
        }
        if (!result.IsSuccess)
        {
            return await ApiFailureAsync(result, "Kulüp bulunamadı.");
        }

        SetStatusMessage("Kulüp silindi.");
        return RedirectToAction(nameof(Index));
    }

    private bool IsAdmin => User.IsInRole(Roles.Yonetici);

    protected override string ListAction => IsAdmin ? nameof(Index) : nameof(Mine);
}
