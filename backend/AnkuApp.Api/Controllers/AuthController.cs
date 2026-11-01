
using AnkuApp.Api.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using Microsoft.AspNetCore.Authorization;

namespace AnkuApp.Api.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
private readonly UserManager<ApplicationUser> _userManager;
private readonly IConfiguration _configuration;

public AuthController(
    UserManager<ApplicationUser> userManager,
    IConfiguration configuration)
{
    _userManager = userManager;
    _configuration = configuration;
}

    [HttpPost("register")]
    public async Task<IActionResult> Register(
        [FromBody] RegisterRequest request)
    {
        var email = request.Email.Trim();

        var existingUser =
            await _userManager.FindByEmailAsync(email);

        if (existingUser != null)
        {
            return BadRequest("Bu e-posta zaten kayıtlı.");
        }

        var user = new ApplicationUser
        {
            UserName = email,
            Email = email,
            FullName = request.FullName.Trim()
        };

        var result = await _userManager.CreateAsync(
            user, request.Password);

        if (!result.Succeeded)
        {
            return BadRequest(result.Errors);
        }

        // Her yeni kullanıcı yalnızca Öğrenci olabilir.
        var roleResult = await _userManager.AddToRoleAsync(
            user, "Öğrenci");

        if (!roleResult.Succeeded)
        {
            await _userManager.DeleteAsync(user);
            return StatusCode(500, "Rol atanamadı.");
        }

        return StatusCode(201, new
        {
            message = "Kullanıcı oluşturuldu.",
            userId = user.Id,
            role = "Öğrenci"
        });
    }
    
    [HttpPost("login")]
    public async Task<IActionResult> Login(
        [FromBody] LoginRequest request)
    {
        var user = await _userManager.FindByEmailAsync(
            request.Email.Trim());

        if (user == null ||
            !await _userManager.CheckPasswordAsync(
                user, request.Password))
        {
            return Unauthorized(new
            {
                message = "E-posta veya şifre hatalı."
            });
        }

        var roles = await _userManager.GetRolesAsync(user);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id),
            new(ClaimTypes.Email, user.Email!),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        foreach (var role in roles)
        {
            claims.Add(new Claim(ClaimTypes.Role, role));
        }

        var key = new SymmetricSecurityKey(
            Convert.FromBase64String(
                _configuration["Jwt:Key"]!));

        var credentials = new SigningCredentials(
            key, SecurityAlgorithms.HmacSha256);

        var expiresAt = DateTime.UtcNow.AddHours(2);

        var token = new JwtSecurityToken(
            issuer: _configuration["Jwt:Issuer"],
            audience: _configuration["Jwt:Audience"],
            claims: claims,
            expires: expiresAt,
            signingCredentials: credentials
        );

        return Ok(new
        {
            accessToken = new JwtSecurityTokenHandler()
                .WriteToken(token),

            expiresAt,
            user = new
            {
                user.Id,
                user.FullName,
                user.Email,
                roles
            }
        });
    }
    [Authorize]
    [HttpGet("me")]
    public IActionResult Me()
    {
        return Ok(new
        {
            userId = User.FindFirstValue(
                ClaimTypes.NameIdentifier),

            email = User.FindFirstValue(
                ClaimTypes.Email),

            roles = User.FindAll(ClaimTypes.Role)
                .Select(r => r.Value)
                .ToArray()
        });
    }
}

public class RegisterRequest
{
    [Required]
    public string FullName { get; set; } = string.Empty;

    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    [MinLength(8)]
    public string Password { get; set; } = string.Empty;
}
public class LoginRequest
{
    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    public string Password { get; set; } = string.Empty;
}
