namespace AnkuApp.Web.Services;

/// <summary><c>GET /api/clubs</c> öğesi. Yetkilinin e-postası yalnızca yöneticiye döner.</summary>
public record ClubDto(
    int Id,
    string Name,
    string? Description,
    string? SocialMediaUrl,
    string? AuthorizedUserName,
    string? AuthorizedUserEmail);

public record ClubRequest(
    string Name,
    string? Description,
    string? SocialMediaUrl,
    string? AuthorizedUserEmail);

/// <summary>AnkuApp.Api'nin <c>/api/clubs</c> uç noktalarını çağırır.</summary>
public class ClubsApiClient(HttpClient http, ILogger<ClubsApiClient> logger) : ApiClientBase(http, logger)
{
    /// <param name="mine">Yalnızca giriş yapan kullanıcının yetkilisi olduğu kulüpler.</param>
    public Task<ApiResult<List<ClubDto>>> ListAsync(bool mine = false, CancellationToken ct = default) =>
        GetAsync<List<ClubDto>>(mine ? "api/clubs?mine=true" : "api/clubs", ct);

    public Task<ApiResult<ClubDto>> GetAsync(int id, CancellationToken ct = default) =>
        GetAsync<ClubDto>($"api/clubs/{id}", ct);

    public Task<ApiResult<ClubDto>> CreateAsync(ClubRequest request, CancellationToken ct = default) =>
        PostAsync<ClubDto>("api/clubs", request, ct);

    public Task<ApiResult> UpdateAsync(int id, ClubRequest request, CancellationToken ct = default) =>
        PutAsync($"api/clubs/{id}", request, ct);

    public Task<ApiResult> DeleteAsync(int id, CancellationToken ct = default) =>
        DeleteAsync($"api/clubs/{id}", ct);
}
