using AnkuApp.Api.Content;
using AnkuApp.Api.Contracts;
using AnkuApp.Api.Data;
using AnkuApp.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace AnkuApp.Api.Controllers;

[ApiController, Route("api/academic-calendar"), Authorize]
public class AcademicCalendarController(AppDbContext db, ContentSyncService sync, TimeProvider clock) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(string? academicYear = null, string? term = null, string? scope = null,
        DateOnly? from = null, DateOnly? to = null, int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        academicYear ??= AcademicCalendarRules.CurrentYear(clock.GetUtcNow());
        var offset = ((long)page - 1) * pageSize;
        if (!AcademicCalendarRules.TryYear(academicYear, out _) ||
            (term is not null && !AcademicCalendarRules.Terms.Contains(term)) ||
            (scope is not null && (string.IsNullOrWhiteSpace(scope) || scope.Length > 200)) || from > to ||
            page < 1 || pageSize is < 1 or > 100 || offset > int.MaxValue)
            return BadRequest(new { message = "Akademik yıl, dönem, tarih aralığı veya sayfalama bilgileri geçersiz." });

        var query = db.AcademicCalendarEntries.AsNoTracking().Where(e => e.AcademicYear == academicYear);
        if (term is not null) query = query.Where(e => e.Term == term);
        if (scope is not null) query = query.Where(e => e.Scope == scope);
        // Aralıkla kesişen kayıtlar: başlangıcı daha eski olsa da devam eden ders/sınav dönemi kaybolmaz.
        if (from is { } start) query = query.Where(e => e.EndDate >= start);
        if (to is { } end) query = query.Where(e => e.StartDate <= end);
        var totalCount = await query.CountAsync(ct);
        var items = await query.OrderBy(e => e.StartDate).ThenBy(e => e.EndDate).ThenBy(e => e.Id)
            .Skip((int)offset).Take(pageSize).ToListAsync(ct);
        return Ok(new { items, page, pageSize, totalCount, academicYear,
            message = totalCount == 0 ? "Bu filtrelere uygun akademik takvim kaydı bulunmuyor." : null });
    }

    [HttpGet("years")]
    public async Task<IActionResult> Years(CancellationToken ct) =>
        Ok(await db.AcademicCalendarEntries.AsNoTracking().Select(e => e.AcademicYear).Distinct().OrderByDescending(y => y).ToListAsync(ct));

    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id, CancellationToken ct) =>
        await db.AcademicCalendarEntries.AsNoTracking().SingleOrDefaultAsync(e => e.Id == id, ct) is { } item ? Ok(item) : NotFound();

    [HttpPost, Authorize(Roles = "Yönetici")]
    public async Task<IActionResult> Create(AcademicCalendarRequest request, CancellationToken ct)
    {
        var item = new AcademicCalendarEntry
        {
            UniqueKey = AcademicCalendarRules.Key(request.AcademicYear, request.Scope.Trim(), request.Term,
                request.Title.Trim(), Guid.NewGuid().ToString("N"))
        };
        Apply(item, request);
        db.AcademicCalendarEntries.Add(item);
        if (!await SaveAsync(ct)) return Duplicate();
        return CreatedAtAction(nameof(Get), new { id = item.Id }, item);
    }

    [HttpPut("{id:int}"), Authorize(Roles = "Yönetici")]
    public async Task<IActionResult> Update(int id, AcademicCalendarRequest request, CancellationToken ct)
    {
        var item = await db.AcademicCalendarEntries.FindAsync([id], ct);
        if (item is null) return NotFound();
        Apply(item, request); // Kaynak anahtarı ve kimlik sabit kalır; manuel düzeltme sonraki yenilemede korunur.
        return await SaveAsync(ct) ? NoContent() : Duplicate();
    }

    [HttpDelete("{id:int}"), Authorize(Roles = "Yönetici")]
    public async Task<IActionResult> Delete(int id, CancellationToken ct)
    {
        var item = await db.AcademicCalendarEntries.FindAsync([id], ct);
        if (item is null) return NotFound();
        db.AcademicCalendarEntries.Remove(item);
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    [HttpPost("refresh"), Authorize(Roles = "Yönetici")]
    public async Task<IActionResult> Refresh(CancellationToken ct)
    {
        var result = await sync.RefreshAsync(ContentSyncService.AcademicCalendar, true, ct);
        return result.Success ? Ok(result) : StatusCode(result.Busy ? 409 : 503, new { message = result.Error });
    }

    private void Apply(AcademicCalendarEntry item, AcademicCalendarRequest request)
    {
        item.AcademicYear = request.AcademicYear;
        item.Scope = request.Scope.Trim();
        item.Term = request.Term;
        item.Title = request.Title.Trim();
        item.Description = request.Description?.Trim();
        item.StartDate = request.StartDate!.Value;
        item.EndDate = request.EndDate!.Value;
        item.SourceName = request.SourceName.Trim();
        item.SourceUrl = ContentSources.NormalizeUrl(request.SourceUrl);
        item.SourcePage = request.SourcePage;
        item.RetrievedAt = clock.GetUtcNow().UtcDateTime;
        item.IsManual = true;
    }

    private ConflictObjectResult Duplicate() => Conflict(new { message = "Aynı yıl, kapsam, dönem, başlık ve tarih aralığı zaten kayıtlı." });
    private async Task<bool> SaveAsync(CancellationToken ct)
    {
        try { await db.SaveChangesAsync(ct); return true; }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation }) { return false; }
    }
}
