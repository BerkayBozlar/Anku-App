using AnkuApp.Web.Auth;
using AnkuApp.Web.Models;
using AnkuApp.Web.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AnkuApp.Web.Controllers;

[Authorize(Roles = Roles.Yonetici)]
public class MealMenusController(MealMenusApiClient api, AnnouncementsApiClient announcements) : PortalController
{
    public async Task<IActionResult> Index(DateOnly? date = null, CancellationToken ct = default)
    {
        if (!ModelState.IsValid) return BadRequest("Geçerli bir tarih girin.");
        var start = date ?? DateOnly.FromDateTime(PortalTime.Now);
        var result = await api.ListAsync(start, ct);
        if (result.Status == ApiStatus.Unauthorized) return await ApiFailureAsync(result);
        var sync = await announcements.SyncStatesAsync(ct);
        return View(new MealMenuListViewModel
        {
            Date = start, Items = result.Value?.Items ?? [], LoadError = result.IsSuccess ? null : result.Message,
            Sync = sync.Value?.FirstOrDefault(s => s.Id == "meal-menus")
        });
    }

    [HttpGet] public IActionResult Create() => View("Form", new MealMenuFormViewModel());

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(MealMenuFormViewModel model, CancellationToken ct)
    {
        model.Id = null;
        if (!ModelState.IsValid) return View("Form", model);
        var result = await api.CreateAsync(model.ToRequest(), ct);
        if (!result.IsSuccess) return TryAddFormErrors<MealMenuFormViewModel>(result) ? View("Form", model) : await ApiFailureAsync(result);
        SetStatusMessage("Öğle menüsü eklendi.");
        return RedirectToAction(nameof(Index), new { date = model.MenuDate?.ToString("yyyy-MM-dd") });
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id, CancellationToken ct)
    {
        var result = await api.FindAsync(id, ct);
        return result.IsSuccess ? View("Form", MealMenuFormViewModel.From(result.Value!)) : await ApiFailureAsync(result);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, MealMenuFormViewModel model, CancellationToken ct)
    {
        model.Id = id;
        if (!ModelState.IsValid) return View("Form", model);
        var result = await api.UpdateAsync(id, model.ToRequest(), ct);
        if (!result.IsSuccess) return TryAddFormErrors<MealMenuFormViewModel>(result) ? View("Form", model) : await ApiFailureAsync(result);
        SetStatusMessage("Öğle menüsü güncellendi. Elle düzenlenen menü otomatik yenilemede korunur.");
        return RedirectToAction(nameof(Index), new { date = model.MenuDate?.ToString("yyyy-MM-dd") });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id, CancellationToken ct)
    {
        var result = await api.RemoveAsync(id, ct);
        if (!result.IsSuccess) return await ApiFailureAsync(result);
        SetStatusMessage("Menü silindi.");
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Refresh(CancellationToken ct)
    {
        var result = await api.RefreshAsync(ct);
        if (result.Status is ApiStatus.Unauthorized or ApiStatus.Forbidden) return await ApiFailureAsync(result);
        if (result.IsSuccess) SetStatusMessage($"Resmî listeden {result.Value!.Imported} günlük menü okundu; {result.Value.Changed} kayıt işlendi.");
        else SetErrorMessage(result.Message ?? "Kaynak yenilenemedi. Elle menü ekleyebilirsiniz.");
        return RedirectToAction(nameof(Index));
    }
}
