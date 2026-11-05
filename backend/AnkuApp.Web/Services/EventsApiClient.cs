namespace AnkuApp.Web.Services;

/// <summary>Etkinlik liste ve ayrıntı yanıtı (docs/api-sozlesmesi.md).</summary>
public record EventDto(
    int Id,
    int ClubId,
    string? ClubName,
    int? CampusLocationId,
    string? CampusLocationName,
    string Title,
    string? Description,
    DateTimeOffset EventDate,
    int? Capacity,
    string Status);

public record EventPage(List<EventDto> Items, int Page, int PageSize, int TotalCount)
{
    public int TotalPages => PageSize <= 0 ? 1 : Math.Max(1, (int)Math.Ceiling(TotalCount / (double)PageSize));
}

/// <param name="EventDate">UTC; JSON'a "Z" ile yazılması için <see cref="DateTimeKind.Utc"/> olmalı.</param>
public record EventRequest(
    int ClubId,
    int? CampusLocationId,
    string Title,
    string? Description,
    DateTime EventDate,
    int Capacity,
    string Status);

public record EventQuery(int Page = 1, int PageSize = 20, string? Search = null, int? ClubId = null);

/// <summary>AnkuApp.Api'nin <c>/api/events</c> uç noktalarını çağırır.</summary>
public class EventsApiClient(HttpClient http, ILogger<EventsApiClient> logger) : ApiClientBase(http, logger)
{
    public Task<ApiResult<EventPage>> ListAsync(EventQuery query, CancellationToken ct = default)
    {
        var parameters = new List<string>
        {
            $"page={query.Page}",
            $"pageSize={query.PageSize}"
        };
        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            parameters.Add($"search={Uri.EscapeDataString(query.Search.Trim())}");
        }
        if (query.ClubId is int clubId)
        {
            parameters.Add($"clubId={clubId}");
        }

        return GetAsync<EventPage>("api/events?" + string.Join('&', parameters), ct);
    }

    public Task<ApiResult<EventDto>> GetAsync(int id, CancellationToken ct = default) =>
        GetAsync<EventDto>($"api/events/{id}", ct);

    public Task<ApiResult<EventDto>> CreateAsync(EventRequest request, CancellationToken ct = default) =>
        PostAsync<EventDto>("api/events", request, ct);

    public Task<ApiResult> UpdateAsync(int id, EventRequest request, CancellationToken ct = default) =>
        PutAsync($"api/events/{id}", request, ct);

    public Task<ApiResult> DeleteAsync(int id, CancellationToken ct = default) =>
        DeleteAsync($"api/events/{id}", ct);
}
