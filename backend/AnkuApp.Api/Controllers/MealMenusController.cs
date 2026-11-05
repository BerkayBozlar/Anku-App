using AnkuApp.Api.Content;
using AnkuApp.Api.Contracts;
using AnkuApp.Api.Data;
using AnkuApp.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace AnkuApp.Api.Controllers;

[ApiController, Route("api/meal-menus"), Authorize]
public class MealMenusController(AppDbContext db, ContentSyncService sync) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(DateOnly? from = null, DateOnly? to = null, CancellationToken ct = default)
    {
        var start = from ?? ContentSources.TurkeyDate(DateTimeOffset.UtcNow);
        var end = to ?? (start <= DateOnly.MaxValue.AddDays(-6) ? start.AddDays(6) : start);
        if (end < start || end.DayNumber - start.DayNumber > 62) return BadRequest(new { message = "En fazla 63 günlük geçerli bir tarih aralığı girin." });
        var items = await db.MealMenus.AsNoTracking().Where(m => m.MenuDate >= start && m.MenuDate <= end).OrderBy(m => m.MenuDate).ToListAsync(ct);
        return Ok(new { items, from = start, to = end });
    }

    [HttpGet("today")]
    public async Task<IActionResult> Today(CancellationToken ct)
    {
        var date = ContentSources.TurkeyDate(DateTimeOffset.UtcNow);
        var menu = await db.MealMenus.AsNoTracking().SingleOrDefaultAsync(m => m.MenuDate == date, ct);
        return Ok(new { date, menu, message = menu is null ? "Bugün için yayımlanmış öğle menüsü bulunmuyor." : null });
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id, CancellationToken ct) =>
        await db.MealMenus.AsNoTracking().SingleOrDefaultAsync(m => m.Id == id, ct) is { } item ? Ok(item) : NotFound();

    [HttpPost, Authorize(Roles = "Yönetici")]
    public async Task<IActionResult> Create(MealMenuRequest request, CancellationToken ct)
    {
        var item = new MealMenu();
        Apply(item, request);
        db.MealMenus.Add(item);
        if (!await SaveAsync(ct)) return Conflict(new { message = "Bu tarih için bir öğle menüsü zaten var; mevcut menüyü düzenleyin." });
        return CreatedAtAction(nameof(Get), new { id = item.Id }, item);
    }

    [HttpPut("{id:int}"), Authorize(Roles = "Yönetici")]
    public async Task<IActionResult> Update(int id, MealMenuRequest request, CancellationToken ct)
    {
        var item = await db.MealMenus.FindAsync([id], ct);
        if (item is null) return NotFound();
        Apply(item, request);
        return await SaveAsync(ct) ? NoContent() : Conflict(new { message = "Bu tarihte başka bir menü var." });
    }

    [HttpDelete("{id:int}"), Authorize(Roles = "Yönetici")]
    public async Task<IActionResult> Delete(int id, CancellationToken ct)
    {
        var item = await db.MealMenus.FindAsync([id], ct);
        if (item is null) return NotFound();
        db.MealMenus.Remove(item);
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    [HttpPost("refresh"), Authorize(Roles = "Yönetici")]
    public async Task<IActionResult> Refresh(CancellationToken ct)
    {
        var result = await sync.RefreshAsync(ContentSyncService.MealMenus, true, ct);
        return result.Success ? Ok(result) : StatusCode(result.Busy ? 409 : 503, new { message = result.Error });
    }

    private static void Apply(MealMenu item, MealMenuRequest request)
    {
        item.MenuDate = request.MenuDate!.Value;
        item.Dishes = request.Dishes.Select(d => d.Trim()).ToArray();
        item.TotalCalories = request.TotalCalories;
        item.SourceName = request.SourceName.Trim();
        item.SourceUrl = ContentSources.NormalizeUrl(request.SourceUrl);
        item.RetrievedAt = DateTime.UtcNow;
        item.IsManual = true;
    }

    private async Task<bool> SaveAsync(CancellationToken ct)
    {
        try { await db.SaveChangesAsync(ct); return true; }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation }) { return false; }
    }
}
