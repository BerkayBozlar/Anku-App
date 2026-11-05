using System.Net.Http.Headers;
using Microsoft.AspNetCore.Authentication;

namespace AnkuApp.Web.Services;

/// <summary>
/// Girişte cookie'ye kaydedilen API token'ını her isteğe <c>Authorization</c> başlığı olarak ekler.
/// </summary>
public class AccessTokenHandler(IHttpContextAccessor accessor) : DelegatingHandler
{
    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var context = accessor.HttpContext;
        if (context is not null)
        {
            var token = await context.GetTokenAsync("access_token");
            if (!string.IsNullOrEmpty(token))
            {
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            }
        }

        return await base.SendAsync(request, cancellationToken);
    }
}
