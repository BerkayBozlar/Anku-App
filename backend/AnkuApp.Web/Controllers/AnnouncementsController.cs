using AnkuApp.Web.Auth;
using AnkuApp.Web.Models;
using AnkuApp.Web.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AnkuApp.Web.Controllers;

[Authorize(Roles = Roles.Yonetici)]
public class AnnouncementsController(AnnouncementsApiClient api) : PortalController
{
    public async Task<IActionResult> Index(int page = 1, string? search = null, CancellationToken ct = default)
    {
        var result = await api.ListAsync(page, search, ct);
        if (result.Status == ApiStatus.Unauthorized) return await ApiFailureAsync(result);
        var sync = await api.SyncStatesAsync(ct);
        return View(new AnnouncementListViewModel
        {
            Page = result.Value, Search = search, LoadError = result.IsSuccess ? null : result.Message,
            Sync = sync.Value?.FirstOrDefault(s => s.Id == "announcements")
        });
    }

    [HttpGet] public IActionResult Create() => View("Form", new AnnouncementFormViewModel());

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(AnnouncementFormViewModel model, CancellationToken ct)
    {
        model.Id = null;
        if (!ModelState.IsValid) return View("Form", model);
        var result = await api.CreateAsync(model.ToRequest(), ct);
        if (!result.IsSuccess) return TryAddFormErrors<AnnouncementFormViewModel>(result) ? View("Form", model) : await ApiFailureAsync(result);
        SetStatusMessage("Duyuru eklendi.");
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id, CancellationToken ct)
    {
        var result = await api.FindAsync(id, ct);
        return result.IsSuccess ? View("Form", AnnouncementFormViewModel.From(result.Value!)) : await ApiFailureAsync(result);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, AnnouncementFormViewModel model, CancellationToken ct)
    {
        model.Id = id;
        if (!ModelState.IsValid) return View("Form", model);
        var result = await api.UpdateAsync(id, model.ToRequest(), ct);
        if (!result.IsSuccess) return TryAddFormErrors<AnnouncementFormViewModel>(result) ? View("Form", model) : await ApiFailureAsync(result);
        SetStatusMessage("Duyuru güncellendi.");
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id, CancellationToken ct)
    {
        var result = await api.RemoveAsync(id, ct);
        if (!result.IsSuccess) return await ApiFailureAsync(result);
        SetStatusMessage("Duyuru silindi.");
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Refresh(CancellationToken ct)
    {
        var result = await api.RefreshAsync(ct);
        if (result.Status is ApiStatus.Unauthorized or ApiStatus.Forbidden) return await ApiFailureAsync(result);
        if (result.IsSuccess) SetStatusMessage($"Kaynak kontrol edildi: {result.Value!.Imported} duyuru okundu, {result.Value.Changed} yeni duyuru eklendi.");
        else SetErrorMessage(result.Message ?? "Kaynak yenilenemedi. Elle duyuru ekleyebilirsiniz.");
        return RedirectToAction(nameof(Index));
    }
}
