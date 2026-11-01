using AnkuApp.Api.Data;
using AnkuApp.Api.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Security.Claims;
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(
        builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddIdentityCore<ApplicationUser>()
    .AddRoles<IdentityRole>()
    .AddEntityFrameworkStores<AppDbContext>();

var jwtKey = builder.Configuration["Jwt:Key"]
    ?? throw new InvalidOperationException(
        "JWT gizli anahtarı bulunamadı.");

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters =
            new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuer =
                    builder.Configuration["Jwt:Issuer"],

                ValidateAudience = true,
                ValidAudience =
                    builder.Configuration["Jwt:Audience"],

                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(
                    Convert.FromBase64String(jwtKey)),

                ValidateLifetime = true,
                ClockSkew = TimeSpan.FromMinutes(1),

                RoleClaimType = ClaimTypes.Role,
                NameClaimType = ClaimTypes.NameIdentifier
            };
    });

builder.Services.AddAuthorization();


// Add services to the container.

builder.Services.AddControllers();
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var roleManager = scope.ServiceProvider
        .GetRequiredService<RoleManager<IdentityRole>>();

    string[] roles =
    {
        "Yönetici",
        "Kulüp Yetkilisi",
        "Öğrenci"
    };

    foreach (var role in roles)
    {
        if (!await roleManager.RoleExistsAsync(role))
        {
            var result = await roleManager.CreateAsync(
                new IdentityRole(role));

            if (!result.Succeeded)
            {
                throw new Exception(
                    $"Rol oluşturulamadı: {role}");
            }
        }
    }
}

if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();

    var userManager = scope.ServiceProvider
        .GetRequiredService<UserManager<ApplicationUser>>();

    var testAccounts = new[]
    {
        new
        {
            Email = "admin@ankuapp.test",
            FullName = "Test Yönetici",
            Role = "Yönetici",
            PasswordKey = "Seed:AdminPassword"
        },
        new
        {
            Email = "kulup@ankuapp.test",
            FullName = "Test Kulüp Yetkilisi",
            Role = "Kulüp Yetkilisi",
            PasswordKey = "Seed:ClubPassword"
        }
    };

    foreach (var account in testAccounts)
    {
        var password = app.Configuration[account.PasswordKey];

        if (string.IsNullOrWhiteSpace(password))
        {
            Console.WriteLine(
                $"Test hesabı atlandı: {account.Email}");
            continue;
        }

        var existingUser =
            await userManager.FindByEmailAsync(account.Email);

        if (existingUser != null)
        {
            if (!await userManager.IsInRoleAsync(
                existingUser, account.Role))
            {
                throw new InvalidOperationException(
                    $"{account.Email} zaten kayıtlı fakat beklenen role sahip değil.");
            }

            continue;
        }

        var user = new ApplicationUser
        {
            UserName = account.Email,
            Email = account.Email,
            FullName = account.FullName
        };

        var createResult =
            await userManager.CreateAsync(user, password);

        if (!createResult.Succeeded)
        {
            throw new InvalidOperationException(
                string.Join("; ",
                    createResult.Errors.Select(e => e.Description)));
        }

        var roleResult =
            await userManager.AddToRoleAsync(user, account.Role);

        if (!roleResult.Succeeded)
        {
            throw new InvalidOperationException(
                string.Join("; ",
                    roleResult.Errors.Select(e => e.Description)));
        }

        Console.WriteLine(
            $"Test hesabı oluşturuldu: {account.Email}");
    }
}


// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();

app.UseAuthentication();

app.UseAuthorization();

app.MapControllers();

app.MapGet("/api/health", () =>
    Results.Ok(new
    {
        status = "ok",
        application = "AnkuApp.Api"
    }));
    
app.Run();
