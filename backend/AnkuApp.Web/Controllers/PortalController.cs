using AnkuApp.Web.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;

namespace AnkuApp.Web.Controllers;

/// <summary>API'yi çağıran portal sayfaları için ortak hata işleme.</summary>
public abstract class PortalController : Controller
{
    public const string StatusMessageKey = "StatusMessage";
    public const string ErrorMessageKey = "ErrorMessage";

    protected void SetStatusMessage(string message) => TempData[StatusMessageKey] = message;

    protected void SetErrorMessage(string message) => TempData[ErrorMessageKey] = message;

    /// <summary>
    /// Formda gösterilebilecek hataları (doğrulama, çakışma, bağlantı) ModelState'e ekler.
    /// Oturum ya da yetki hatalarında false döner; o durumda <see cref="ApiFailureAsync"/> kullanılır.
    /// </summary>
    protected bool TryAddFormErrors<TModel>(ApiResult result)
    {
        if (result.Status is not (ApiStatus.Invalid or ApiStatus.Conflict or ApiStatus.Failed))
        {
            return false;
        }

        var added = false;
        foreach (var (key, messages) in result.Errors ?? new Dictionary<string, string[]>())
        {
            var field = FormFieldFor<TModel>(key);
            foreach (var message in messages)
            {
                ModelState.AddModelError(field, message);
                added = true;
            }
        }

        if (!added)
        {
            ModelState.AddModelError(string.Empty, result.Message ?? "İşlem tamamlanamadı.");
        }

        return true;
    }

    /// <summary>
    /// Süresi dolan oturumu kapatır, yetkisiz işlemi erişim sayfasına,
    /// bulunamayan kaydı listeye yönlendirir.
    /// </summary>
    protected async Task<IActionResult> ApiFailureAsync(ApiResult result, string notFoundMessage = "Kayıt bulunamadı.")
    {
        switch (result.Status)
        {
            case ApiStatus.Unauthorized:
                await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
                return RedirectToAction("Login", "Account", new { returnUrl = Request.Path + Request.QueryString });
            case ApiStatus.Forbidden:
                return RedirectToAction("AccessDenied", "Account");
            case ApiStatus.NotFound:
                SetErrorMessage(notFoundMessage);
                return RedirectToAction(ListAction);
            default:
                SetErrorMessage(result.Message ?? "İşlem tamamlanamadı.");
                return RedirectToAction(ListAction);
        }
    }

    /// <summary>Hata sonrası dönülecek liste sayfası.</summary>
    protected virtual string ListAction => "Index";

    // API alan adları "Title", "title" ya da "$.title" biçiminde gelebilir
    private string FormFieldFor<TModel>(string apiKey)
    {
        var name = apiKey.StartsWith("$.") ? apiKey[2..] : apiKey;
        var property = MetadataProvider.GetMetadataForType(typeof(TModel)).Properties
            .FirstOrDefault(p => string.Equals(p.PropertyName, name, StringComparison.OrdinalIgnoreCase));
        return property?.PropertyName ?? string.Empty;
    }
}
