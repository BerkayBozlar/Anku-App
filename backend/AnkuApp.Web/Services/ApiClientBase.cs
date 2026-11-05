using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace AnkuApp.Web.Services;

/// <summary>
/// Token gerektiren API çağrıları için ortak gönderme ve hata eşleme.
/// </summary>
public abstract class ApiClientBase(HttpClient http, ILogger logger)
{
    protected async Task<ApiResult<T>> GetAsync<T>(string url, CancellationToken ct)
    {
        var (response, failure) = await SendAsync(() => http.GetAsync(url, ct), ct);
        if (failure is not null)
        {
            return ApiResult<T>.From(failure);
        }

        using (response)
        {
            return await ReadBodyAsync<T>(response!, ct);
        }
    }

    protected async Task<ApiResult<T>> PostAsync<T>(string url, object body, CancellationToken ct)
    {
        var (response, failure) = await SendAsync(() => http.PostAsJsonAsync(url, body, ct), ct);
        if (failure is not null)
        {
            return ApiResult<T>.From(failure);
        }

        using (response)
        {
            return await ReadBodyAsync<T>(response!, ct);
        }
    }

    protected async Task<ApiResult> PutAsync(string url, object body, CancellationToken ct)
    {
        var (response, failure) = await SendAsync(() => http.PutAsJsonAsync(url, body, ct), ct);
        response?.Dispose();
        return failure ?? ApiResult.Ok();
    }

    protected async Task<ApiResult> DeleteAsync(string url, CancellationToken ct)
    {
        var (response, failure) = await SendAsync(() => http.DeleteAsync(url, ct), ct);
        response?.Dispose();
        return failure ?? ApiResult.Ok();
    }

    /// <summary>Başarılı yanıtı döndürür; aksi halde yanıtı kapatıp hatayı döndürür.</summary>
    private async Task<(HttpResponseMessage? Response, ApiResult? Failure)> SendAsync(
        Func<Task<HttpResponseMessage>> send, CancellationToken ct)
    {
        HttpResponseMessage response;
        try
        {
            response = await send();
        }
        catch (HttpRequestException ex)
        {
            logger.LogWarning(ex, "API'ye ulaşılamadı: {BaseAddress}", http.BaseAddress);
            return (null, new ApiResult(ApiStatus.Failed, "API'ye ulaşılamadı. Lütfen daha sonra tekrar deneyin."));
        }
        catch (TaskCanceledException) when (!ct.IsCancellationRequested)
        {
            return (null, new ApiResult(ApiStatus.Failed, "API zamanında yanıt vermedi."));
        }

        if (response.IsSuccessStatusCode)
        {
            return (response, null);
        }

        using (response)
        {
            var (message, errors) = await ApiErrors.ReadAsync(response, ct);
            var status = response.StatusCode switch
            {
                HttpStatusCode.Unauthorized => ApiStatus.Unauthorized,
                HttpStatusCode.Forbidden => ApiStatus.Forbidden,
                HttpStatusCode.NotFound => ApiStatus.NotFound,
                HttpStatusCode.BadRequest => ApiStatus.Invalid,
                HttpStatusCode.Conflict => ApiStatus.Conflict,
                _ => ApiStatus.Failed
            };

            if (status == ApiStatus.Failed)
            {
                logger.LogWarning("API {Status} döndürdü: {Url}", (int)response.StatusCode, response.RequestMessage?.RequestUri);
                message ??= $"API isteği başarısız oldu ({(int)response.StatusCode}).";
            }

            return (null, new ApiResult(status, message, errors));
        }
    }

    private static async Task<ApiResult<T>> ReadBodyAsync<T>(HttpResponseMessage response, CancellationToken ct)
    {
        try
        {
            var value = await response.Content.ReadFromJsonAsync<T>(ct);
            return value is null
                ? new ApiResult<T>(ApiStatus.Failed, Message: "API'den boş yanıt alındı.")
                : ApiResult<T>.Ok(value);
        }
        catch (JsonException)
        {
            return new ApiResult<T>(ApiStatus.Failed, Message: "API'den beklenmeyen bir yanıt alındı.");
        }
    }
}
