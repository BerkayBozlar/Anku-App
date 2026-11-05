using AnkuApp.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AnkuApp.Api.Controllers;

[ApiController, Route("api/content-sync"), Authorize(Roles = "Yönetici")]
public class ContentSyncController(AppDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct) =>
        Ok(await db.ContentSyncStates.AsNoTracking().OrderBy(s => s.Id).ToListAsync(ct));
}
