using Microsoft.Extensions.Options;

namespace AnkuApp.Api.Content;

public sealed class ContentRefreshWorker(
    IServiceScopeFactory scopes, IOptions<ContentSourceOptions> options, ILogger<ContentRefreshWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.Value.Enabled) return;
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(30));
        do
        {
            foreach (var kind in new[] { ContentSyncService.Announcements, ContentSyncService.MealMenus })
            {
                try
                {
                    using var scope = scopes.CreateScope();
                    await scope.ServiceProvider.GetRequiredService<ContentSyncService>().RefreshAsync(kind, force: false, stoppingToken);
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { return; }
                catch (Exception ex) { logger.LogError(ex, "Günlük içerik kontrolü tamamlanamadı: {Source}", kind); }
            }
        } while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
