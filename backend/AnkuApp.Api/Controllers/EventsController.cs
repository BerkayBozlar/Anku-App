
using AnkuApp.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using AnkuApp.Api.Contracts;
using AnkuApp.Api.Models;
using System.Security.Claims;

namespace AnkuApp.Api.Controllers;

[ApiController]
[Route("api/events")]
[Authorize]
public class EventsController : ControllerBase
{
    private readonly AppDbContext _context;

    public EventsController(AppDbContext context)
    {
        _context = context;
    }

    // GET /api/events
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] string? search = null,
        [FromQuery] int? clubId = null,
        [FromQuery] DateTimeOffset? from = null)
    {
        if (page < 1 || pageSize < 1 || pageSize > 100)
        {
            return BadRequest(new
            {
                message = "Sayfalama bilgileri geçersiz."
            });
        }

        var query = _context.Events.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();

            query = query.Where(e =>
                EF.Functions.ILike(e.Title, $"%{term}%"));
        }

        if (clubId.HasValue)
        {
            query = query.Where(e =>
                e.ClubId == clubId.Value);
        }

        if (from.HasValue)
        {
            var fromUtc = from.Value.UtcDateTime;

            query = query.Where(e =>
                e.EventDate >= fromUtc);
        }

        var totalCount = await query.CountAsync();

        var items = await query
            .OrderBy(e => e.EventDate)
            .ThenBy(e => e.Id)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(e => new
            {
                e.Id,
                e.ClubId,
                ClubName = e.Club.Name,
                e.CampusLocationId,
                e.Title,
                e.Description,
                e.EventDate,
                e.Capacity,
                Status = e.Status.ToString()
            })
            .ToListAsync();

        return Ok(new
        {
            items,
            page,
            pageSize,
            totalCount
        });
    }

    // GET /api/events/5
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var eventItem = await _context.Events
            .AsNoTracking()
            .Where(e => e.Id == id)
            .Select(e => new
            {
                e.Id,
                e.ClubId,
                ClubName = e.Club.Name,
                e.CampusLocationId,
                CampusLocationName = e.CampusLocation != null
                    ? e.CampusLocation.Name
                    : null,
                e.Title,
                e.Description,
                e.EventDate,
                e.Capacity,
                Status = e.Status.ToString()
            })
            .FirstOrDefaultAsync();

        if (eventItem == null)
        {
            return NotFound(new
            {
                message = "Etkinlik bulunamadı."
            });
        }

        return Ok(eventItem);
    }

    [HttpPost]
    [Authorize(Roles = "Yönetici,Kulüp Yetkilisi")]
    public async Task<IActionResult> Create(
        [FromBody] EventUpsertRequest request)
    {
        // 1. Başlık kontrolü
        if (string.IsNullOrWhiteSpace(request.Title))
        {
            return BadRequest(new
            {
                message = "Etkinlik başlığı boş olamaz."
            });
        }

        // 2. Tarih kontrolü
        if (request.EventDate <= DateTimeOffset.UtcNow)
        {
            return BadRequest(new
            {
                message = "Etkinlik tarihi gelecekte olmalıdır."
            });
        }

        // 3. Durum kontrolü
        if (!Enum.TryParse<EventStatus>(
                request.Status, true, out var status)
            || !Enum.IsDefined(status))
        {
            return BadRequest(new
            {
                message = "Geçersiz etkinlik durumu."
            });
        }

        // 4. Kulüp kontrolü
        var club = await _context.Clubs
            .AsNoTracking()
            .FirstOrDefaultAsync(c => c.Id == request.ClubId);

        if (club == null)
        {
            return BadRequest(new
            {
                message = "Belirtilen kulüp bulunamadı."
            });
        }

        // 5. Kulüp yetkilisi yalnızca kendi kulübü için
        // etkinlik oluşturabilir.
        var userId = User.FindFirstValue(
            ClaimTypes.NameIdentifier);

        if (!User.IsInRole("Yönetici") &&
            (string.IsNullOrEmpty(userId) ||
            club.AuthorizedUserId != userId))
        {
            return Forbid();
        }

        // 6. Kampüs konumu kontrolü
        if (request.CampusLocationId.HasValue)
        {
            var locationExists = await _context
                .CampusLocations
                .AnyAsync(c =>
                    c.Id == request.CampusLocationId.Value);

            if (!locationExists)
            {
                return BadRequest(new
                {
                    message = "Kampüs konumu bulunamadı."
                });
            }
        }

        // 7. Etkinliği oluştur
        var eventItem = new AnkuApp.Api.Models.Event
        {
            ClubId = request.ClubId,
            CampusLocationId = request.CampusLocationId,
            Title = request.Title.Trim(),
            Description = request.Description?.Trim(),
            EventDate = request.EventDate.UtcDateTime,
            Capacity = request.Capacity,
            Status = status
        };

        _context.Events.Add(eventItem);
        await _context.SaveChangesAsync();

        // 8. Başarılı yanıt
        return CreatedAtAction(
            nameof(GetById),
            new { id = eventItem.Id },
            new
            {
                eventItem.Id,
                eventItem.ClubId,
                eventItem.CampusLocationId,
                eventItem.Title,
                eventItem.Description,
                eventItem.EventDate,
                eventItem.Capacity,
                Status = eventItem.Status.ToString()
            });
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Yönetici,Kulüp Yetkilisi")]
    public async Task<IActionResult> Update(
        int id,
        [FromBody] EventUpsertRequest request)
    {
        // Güncellenecek etkinliği bul.
        var eventItem = await _context.Events
            .Include(e => e.Club)
            .FirstOrDefaultAsync(e => e.Id == id);

        if (eventItem == null)
        {
            return NotFound(new
            {
                message = "Etkinlik bulunamadı."
            });
        }

        // Kulüp yetkilisi sadece kendi kulübünün
        // etkinliğini güncelleyebilir.
        var userId = User.FindFirstValue(
            ClaimTypes.NameIdentifier);

        if (!User.IsInRole("Yönetici"))
        {
            if (string.IsNullOrEmpty(userId) ||
                eventItem.Club.AuthorizedUserId != userId)
            {
                return Forbid();
            }

            // Başka kulübe etkinlik taşıyamaz.
            if (request.ClubId != eventItem.ClubId)
            {
                return Forbid();
            }
        }

        // Giriş verilerini doğrula.
        if (string.IsNullOrWhiteSpace(request.Title))
        {
            return BadRequest(new
            {
                message = "Etkinlik başlığı boş olamaz."
            });
        }

        if (request.EventDate <= DateTimeOffset.UtcNow)
        {
            return BadRequest(new
            {
                message = "Etkinlik tarihi gelecekte olmalıdır."
            });
        }

        if (!Enum.TryParse<EventStatus>(
                request.Status, true, out var status)
            || !Enum.IsDefined(status))
        {
            return BadRequest(new
            {
                message = "Geçersiz etkinlik durumu."
            });
        }

        // Gönderilen kulüp mevcut mu?
        var clubExists = await _context.Clubs
            .AnyAsync(c => c.Id == request.ClubId);

        if (!clubExists)
        {
            return BadRequest(new
            {
                message = "Belirtilen kulüp bulunamadı."
            });
        }

        // Kampüs konumu varsa doğrula.
        if (request.CampusLocationId.HasValue)
        {
            var locationExists = await _context
                .CampusLocations
                .AnyAsync(c =>
                    c.Id == request.CampusLocationId.Value);

            if (!locationExists)
            {
                return BadRequest(new
                {
                    message = "Kampüs konumu bulunamadı."
                });
            }
        }

        // Bilgileri güncelle.
        eventItem.ClubId = request.ClubId;
        eventItem.CampusLocationId =
            request.CampusLocationId;

        eventItem.Title = request.Title.Trim();
        eventItem.Description =
            request.Description?.Trim();

        eventItem.EventDate = request.EventDate.UtcDateTime;
        eventItem.Capacity = request.Capacity;
        eventItem.Status = status;

        await _context.SaveChangesAsync();

        return NoContent();
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Yönetici,Kulüp Yetkilisi")]
    public async Task<IActionResult> Delete(int id)
    {
        // Silinecek etkinliği bul.
        var eventItem = await _context.Events
            .Include(e => e.Club)
            .FirstOrDefaultAsync(e => e.Id == id);

        if (eventItem == null)
        {
            return NotFound(new
            {
                message = "Etkinlik bulunamadı."
            });
        }

        // Kulüp yetkilisi yalnızca kendi kulübünün
        // etkinliğini silebilir.
        var userId = User.FindFirstValue(
            ClaimTypes.NameIdentifier);

        if (!User.IsInRole("Yönetici") &&
            (string.IsNullOrEmpty(userId) ||
            eventItem.Club.AuthorizedUserId != userId))
        {
            return Forbid();
        }

        // Etkinliği PostgreSQL'den sil.
        _context.Events.Remove(eventItem);

        await _context.SaveChangesAsync();

        return NoContent();
    }

}
