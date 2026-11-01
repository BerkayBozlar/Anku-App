using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace AnkuApp.Web.Services;

public record ApiUser(string Id, string FullName, string Email, string Role);

public record LoginResponse(string AccessToken, DateTimeOffset ExpiresAt, ApiUser User);

public enum LoginStatus
{
    Success,
    InvalidCredentials,
    Failed
}

public record LoginResult(LoginStatus Status, LoginResponse? Response = null, string? Error = null);

/// <summary>
/// AnkuApp.Api'nin kimlik doğrulama uç noktalarını çağırır.
/// </summary>
public class AuthApiClient(HttpClient http, ILogger<AuthApiClient> logger)
{
    public async Task<LoginResult> LoginAsync(string email, string password, CancellationToken ct = default)
    {
        HttpResponseMessage response;
        try
        {
            response = await http.PostAsJsonAsync("api/auth/login", new { email, password }, ct);
        }
        catch (HttpRequestException ex)
        {
            logger.LogWarning(ex, "API'ye ulaşılamadı: {BaseAddress}", http.BaseAddress);
            return new LoginResult(LoginStatus.Failed, Error: "API'ye ulaşılamadı. Lütfen daha sonra tekrar deneyin.");
        }
        catch (TaskCanceledException) when (!ct.IsCancellationRequested)
        {
            return new LoginResult(LoginStatus.Failed, Error: "API zamanında yanıt vermedi.");
        }

        using (response)
        {
            if (response.StatusCode == HttpStatusCode.Unauthorized)
            {
                return new LoginResult(LoginStatus.InvalidCredentials);
            }

            if (!response.IsSuccessStatusCode)
            {
                var detail = await ReadProblemDetailAsync(response, ct);
                return new LoginResult(LoginStatus.Failed, Error: detail ?? $"Giriş başarısız ({(int)response.StatusCode}).");
            }

            var body = await response.Content.ReadFromJsonAsync<LoginResponse>(ct);
            if (body is null || string.IsNullOrEmpty(body.AccessToken))
            {
                return new LoginResult(LoginStatus.Failed, Error: "API'den beklenmeyen bir yanıt alındı.");
            }

            return new LoginResult(LoginStatus.Success, body);
        }
    }

    private static async Task<string?> ReadProblemDetailAsync(HttpResponseMessage response, CancellationToken ct)
    {
        try
        {
            using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
            return doc.RootElement.TryGetProperty("detail", out var detail) ? detail.GetString() : null;
        }
        catch (JsonException)
        {
            return null;
        }
    }
}
