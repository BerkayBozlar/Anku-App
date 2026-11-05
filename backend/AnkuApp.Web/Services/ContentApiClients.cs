namespace AnkuApp.Web.Services;

public record AnnouncementDto(int Id, string Title, string? Summary, string SourceName, string SourceUrl,
    DateTimeOffset PublishedAt, DateTimeOffset RetrievedAt, bool IsManual);
public record AnnouncementPage(List<AnnouncementDto> Items, int Page, int PageSize, int TotalCount);
public record AnnouncementRequest(string Title, string? Summary, string SourceName, string SourceUrl, DateTimeOffset PublishedAt);
public record MealMenuDto(int Id, DateOnly MenuDate, string[] Dishes, int? TotalCalories,
    string SourceName, string SourceUrl, DateTimeOffset RetrievedAt, bool IsManual);
public record MealMenuPage(List<MealMenuDto> Items, DateOnly From, DateOnly To);
public record MealMenuRequest(DateOnly MenuDate, string[] Dishes, int? TotalCalories, string SourceName, string SourceUrl);
public record ContentSyncDto(string Id, DateTimeOffset? LastAttemptAt, DateTimeOffset? LastSuccessAt, string? LastError);
public record ContentRefreshDto(bool Success, int Imported, int Changed);

public class AnnouncementsApiClient(HttpClient http, ILogger<AnnouncementsApiClient> logger) : ApiClientBase(http, logger)
{
    public Task<ApiResult<AnnouncementPage>> ListAsync(int page, string? search, CancellationToken ct) =>
        GetAsync<AnnouncementPage>($"api/announcements?page={page}&search={Uri.EscapeDataString(search ?? "")}", ct);
    public Task<ApiResult<AnnouncementDto>> FindAsync(int id, CancellationToken ct) => GetAsync<AnnouncementDto>($"api/announcements/{id}", ct);
    public Task<ApiResult<AnnouncementDto>> CreateAsync(AnnouncementRequest request, CancellationToken ct) => PostAsync<AnnouncementDto>("api/announcements", request, ct);
    public Task<ApiResult> UpdateAsync(int id, AnnouncementRequest request, CancellationToken ct) => PutAsync($"api/announcements/{id}", request, ct);
    public Task<ApiResult> RemoveAsync(int id, CancellationToken ct) => DeleteAsync($"api/announcements/{id}", ct);
    public Task<ApiResult<ContentRefreshDto>> RefreshAsync(CancellationToken ct) => PostAsync<ContentRefreshDto>("api/announcements/refresh", new { }, ct);
    public Task<ApiResult<List<ContentSyncDto>>> SyncStatesAsync(CancellationToken ct) => GetAsync<List<ContentSyncDto>>("api/content-sync", ct);
}

public class MealMenusApiClient(HttpClient http, ILogger<MealMenusApiClient> logger) : ApiClientBase(http, logger)
{
    public Task<ApiResult<MealMenuPage>> ListAsync(DateOnly date, CancellationToken ct) => GetAsync<MealMenuPage>($"api/meal-menus?from={date:yyyy-MM-dd}", ct);
    public Task<ApiResult<MealMenuDto>> FindAsync(int id, CancellationToken ct) => GetAsync<MealMenuDto>($"api/meal-menus/{id}", ct);
    public Task<ApiResult<MealMenuDto>> CreateAsync(MealMenuRequest request, CancellationToken ct) => PostAsync<MealMenuDto>("api/meal-menus", request, ct);
    public Task<ApiResult> UpdateAsync(int id, MealMenuRequest request, CancellationToken ct) => PutAsync($"api/meal-menus/{id}", request, ct);
    public Task<ApiResult> RemoveAsync(int id, CancellationToken ct) => DeleteAsync($"api/meal-menus/{id}", ct);
    public Task<ApiResult<ContentRefreshDto>> RefreshAsync(CancellationToken ct) => PostAsync<ContentRefreshDto>("api/meal-menus/refresh", new { }, ct);
}
