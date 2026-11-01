using System.Security.Claims;
using AnkuApp.Web.Auth;
using AnkuApp.Web.Models;
using AnkuApp.Web.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AnkuApp.Web.Controllers;

[AllowAnonymous]
public class AccountController(AuthApiClient authApi) : Controller
{
    [HttpGet]
    public IActionResult Login(string? returnUrl = null)
    {
        if (User.Identity?.IsAuthenticated == true)
        {
            return RedirectToLocal(returnUrl);
        }

        return View(new LoginViewModel { ReturnUrl = returnUrl });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Login(LoginViewModel model, CancellationToken ct)
    {
        if (!ModelState.IsValid)
        {
            return View(model);
        }

        var result = await authApi.LoginAsync(model.Email, model.Password, ct);

        if (result.Status == LoginStatus.InvalidCredentials)
        {
            ModelState.AddModelError(string.Empty, "E-posta veya parola hatalı.");
            return View(model);
        }

        if (result.Status == LoginStatus.Failed || result.Response is null)
        {
            ModelState.AddModelError(string.Empty, result.Error ?? "Giriş yapılamadı.");
            return View(model);
        }

        var login = result.Response;
        if (!Roles.CanUsePortal(login.User.Role))
        {
            ModelState.AddModelError(string.Empty,
                "Bu portal yalnızca yönetici ve kulüp yetkilileri içindir. Öğrenciler AnküApp mobil uygulamasını kullanabilir.");
            return View(model);
        }

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, login.User.Id),
            new(ClaimTypes.Name, login.User.FullName),
            new(ClaimTypes.Email, login.User.Email),
            new(ClaimTypes.Role, login.User.Role)
        };
        var principal = new ClaimsPrincipal(
            new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme));

        var properties = new AuthenticationProperties
        {
            IsPersistent = model.RememberMe,
            // Oturum, API token'ı ile aynı anda sona erer
            ExpiresUtc = login.ExpiresAt
        };
        // Sonraki haftalarda API'ye yapılacak istekler için
        properties.StoreTokens([new AuthenticationToken { Name = "access_token", Value = login.AccessToken }]);

        await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal, properties);

        return RedirectToLocal(model.ReturnUrl);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Logout()
    {
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return RedirectToAction(nameof(Login));
    }

    [HttpGet]
    public IActionResult AccessDenied() => View();

    private IActionResult RedirectToLocal(string? returnUrl) =>
        Url.IsLocalUrl(returnUrl) ? Redirect(returnUrl) : RedirectToAction("Index", "Home");
}
