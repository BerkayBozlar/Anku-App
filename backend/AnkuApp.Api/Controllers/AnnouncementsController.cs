using AnkuApp.Api.Content;
using AnkuApp.Api.Contracts;
using AnkuApp.Api.Data;
using AnkuApp.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace AnkuApp.Api.Controllers;

[ApiController, Route("api/announcements"), Authorize]
public class AnnouncementsController(AppDbContext db, ContentSyncService sync) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(int page = 1, int pageSize = 20, string? search = null, CancellationToken ct = default)
    {
        var offset = ((long)page - 1) * pageSize;
        if (page < 1 || pageSize is < 1 or > 100 || offset > int.MaxValue) return BadRequest(new { message = "Sayfalama bilgileri geçersiz." });
        var query = db.Announcements.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(search)) query = query.Where(a => EF.Functions.ILike(a.Title, $"%{search.Trim()}%"));
        var totalCount = await query.CountAsync(ct);
        var items = await query.OrderByDescending(a => a.PublishedAt).ThenByDescending(a => a.Id)
            .Skip((int)offset).Take(pageSize).ToListAsync(ct);
        return Ok(new { items, page, pageSize, totalCount });
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id, CancellationToken ct) =>
        await db.Announcements.AsNoTracking().SingleOrDefaultAsync(a => a.Id == id, ct) is { } item ? Ok(item) : NotFound();

    [HttpPost, Authorize(Roles = "Yönetici")]
    public async Task<IActionResult> Create(AnnouncementRequest request, CancellationToken ct)
    {
        var item = new Announcement();
        Apply(item, request);
        db.Announcements.Add(item);
        if (!await SaveAsync(ct)) return Conflict(new { message = "Bu kaynak bağlantısına ait duyuru zaten kayıtlı." });
        return CreatedAtAction(nameof(Get), new { id = item.Id }, item);
    }

    [HttpPut("{id:int}"), Authorize(Roles = "Yönetici")]
    public async Task<IActionResult> Update(int id, AnnouncementRequest request, CancellationToken ct)
    {
        var item = await db.Announcements.FindAsync([id], ct);
        if (item is null) return NotFound();
        Apply(item, request);
        return await SaveAsync(ct) ? NoContent() : Conflict(new { message = "Bu kaynak bağlantısına ait duyuru zaten kayıtlı." });
    }

    [HttpDelete("{id:int}"), Authorize(Roles = "Yönetici")]
    public async Task<IActionResult> Delete(int id, CancellationToken ct)
    {
        var item = await db.Announcements.FindAsync([id], ct);
        if (item is null) return NotFound();
        db.Announcements.Remove(item);
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    [HttpPost("refresh"), Authorize(Roles = "Yönetici")]
    public async Task<IActionResult> Refresh(CancellationToken ct)
    {
        var result = await sync.RefreshAsync(ContentSyncService.Announcements, true, ct);
        return result.Success ? Ok(result) : StatusCode(result.Busy ? 409 : 503, new { message = result.Error });
    }

    private static void Apply(Announcement item, AnnouncementRequest request)
    {
        item.Title = request.Title.Trim();
        item.Summary = request.Summary?.Trim();
        item.SourceName = request.SourceName.Trim();
        item.SourceUrl = ContentSources.NormalizeUrl(request.SourceUrl);
        item.UniqueKey = ContentSources.UniqueKey(item.SourceUrl);
        item.PublishedAt = request.PublishedAt!.Value.UtcDateTime;
        item.RetrievedAt = DateTime.UtcNow;
        item.IsManual = true;
    }

    private async Task<bool> SaveAsync(CancellationToken ct)
    {
        try { await db.SaveChangesAsync(ct); return true; }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation }) { return false; }
    }
}
