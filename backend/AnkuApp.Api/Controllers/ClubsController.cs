
using AnkuApp.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AnkuApp.Api.Controllers;

[ApiController]
[Route("api/clubs")]
[Authorize]
public class ClubsController : ControllerBase
{
    private readonly AppDbContext _context;

    public ClubsController(AppDbContext context)
    {
        _context = context;
    }

    // GET /api/clubs
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var clubs = await _context.Clubs
            .AsNoTracking()
            .OrderBy(c => c.Name)
            .Select(c => new
            {
                c.Id,
                c.Name,
                c.Description
            })
            .ToListAsync();

        return Ok(clubs);
    }
}
