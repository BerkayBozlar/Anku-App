using System.Data.Common;
using AnkuApp.Api.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace AnkuApp.Api.Content;

public sealed class ContentSyncGate
{
    public SemaphoreSlim Announcements { get; } = new(1, 1);
    public SemaphoreSlim MealMenus { get; } = new(1, 1);
}

public record ContentSyncResult(bool Success, int Imported, int Changed, string? Error = null, bool Skipped = false, bool Busy = false);

public sealed class ContentSyncService(
    AppDbContext db, OfficialContentClient source, ContentSyncGate gates,
    IOptions<ContentSourceOptions> options, TimeProvider clock, ILogger<ContentSyncService> logger)
{
    public const string Announcements = "announcements";
    public const string MealMenus = "meal-menus";

    public static bool IsDue(DateTime? lastAttempt, DateTimeOffset now) =>
        lastAttempt is null || ContentSources.TurkeyDate(new DateTimeOffset(DateTime.SpecifyKind(lastAttempt.Value, DateTimeKind.Utc)))
            < ContentSources.TurkeyDate(now);

    public async Task<ContentSyncResult> RefreshAsync(string kind, bool force, CancellationToken ct)
    {
        var gate = kind switch
        {
            Announcements => gates.Announcements,
            MealMenus => gates.MealMenus,
            _ => throw new ArgumentException("Bilinmeyen kaynak.", nameof(kind))
        };
        if (!await gate.WaitAsync(0, ct)) return new(false, 0, 0, "Bu kaynak zaten yenileniyor.", Busy: true);
        try
        {
            var now = clock.GetUtcNow();
            var state = await db.ContentSyncStates.AsNoTracking().SingleOrDefaultAsync(s => s.Id == kind, ct);
            if (!force && !IsDue(state?.LastAttemptAt, now)) return new(true, 0, 0, Skipped: true);
            var attemptedAt = now.UtcDateTime;
            await db.Database.ExecuteSqlInterpolatedAsync($"""
                INSERT INTO "ContentSyncStates" ("Id", "LastAttemptAt") VALUES ({kind}, {attemptedAt})
                ON CONFLICT ("Id") DO UPDATE SET "LastAttemptAt" = EXCLUDED."LastAttemptAt"
                """, ct);

            try
            {
                using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
                timeout.CancelAfter(TimeSpan.FromSeconds(25));
                var bytes = await source.DownloadAsync(kind == Announcements ? options.Value.AnnouncementsUrl : options.Value.MealMenusUrl, timeout.Token);
                var announcements = kind == Announcements ? OfficialContentParser.Announcements(bytes) : [];
                var menus = kind == MealMenus ? OfficialContentParser.MealMenus(bytes) : [];
                var changed = 0;
                await using var transaction = await db.Database.BeginTransactionAsync(ct);
                foreach (var item in announcements)
                {
                    var key = ContentSources.UniqueKey(item.SourceUrl);
                    changed += await db.Database.ExecuteSqlInterpolatedAsync($"""
                        INSERT INTO "Announcements" ("Title", "Summary", "SourceName", "SourceUrl", "UniqueKey", "PublishedAt", "RetrievedAt", "IsManual")
                        VALUES ({item.Title}, {item.Summary}, {"Ankara Üniversitesi Öğrenci İşleri"}, {item.SourceUrl}, {key}, {item.PublishedAt}, {attemptedAt}, {false})
                        ON CONFLICT ("UniqueKey") DO NOTHING
                        """, ct);
                }
                foreach (var menu in menus)
                {
                    var url = options.Value.MealMenusUrl;
                    changed += await db.Database.ExecuteSqlInterpolatedAsync($"""
                        INSERT INTO "MealMenus" ("MenuDate", "Dishes", "TotalCalories", "SourceName", "SourceUrl", "RetrievedAt", "IsManual")
                        VALUES ({menu.MenuDate}, {menu.Dishes}, {menu.TotalCalories}, {"Ankara Üniversitesi SKS"}, {url}, {attemptedAt}, {false})
                        ON CONFLICT ("MenuDate") DO UPDATE SET "Dishes" = EXCLUDED."Dishes", "TotalCalories" = EXCLUDED."TotalCalories",
                            "SourceUrl" = EXCLUDED."SourceUrl", "RetrievedAt" = EXCLUDED."RetrievedAt"
                        WHERE NOT "MealMenus"."IsManual"
                        """, ct);
                }
                await db.Database.ExecuteSqlInterpolatedAsync($"""
                    UPDATE "ContentSyncStates" SET "LastSuccessAt" = {attemptedAt}, "LastError" = NULL WHERE "Id" = {kind}
                    """, ct);
                await transaction.CommitAsync(ct);
                return new(true, announcements.Count + menus.Count, changed);
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
            catch (Exception ex) when (ex is HttpRequestException or OperationCanceledException or InvalidDataException or IOException
                or System.Xml.XmlException or FormatException or ArgumentException or System.Text.RegularExpressions.RegexMatchTimeoutException
                or DbException or DbUpdateException)
            {
                // Kaynak veya kayıt hatası mevcut veriyi silmez (işlem geri alınır); son başarı zamanı korunur.
                var error = ex switch
                {
                    OperationCanceledException => "Resmî kaynak zamanında yanıt vermedi.",
                    DbException or DbUpdateException => "İçerik veritabanına kaydedilemedi. Mevcut veriler korundu; daha sonra tekrar yenileyin.",
                    _ => "Resmî kaynak okunamadı veya biçimi değişti. Mevcut veriler korundu; elle giriş yapabilir veya tekrar yenileyebilirsiniz."
                };
                logger.LogWarning(ex, "İçerik kaynağı yenilenemedi: {Source}", kind);
                try
                {
                    await db.Database.ExecuteSqlInterpolatedAsync($"""
                        UPDATE "ContentSyncStates" SET "LastError" = {error} WHERE "Id" = {kind}
                        """, ct);
                }
                catch (Exception stateError) when (stateError is DbException or DbUpdateException)
                {
                    // Veritabanı erişilemiyorsa hata durumu yazılamaz; yanıt yine anlaşılır mesajla döner.
                    logger.LogWarning(stateError, "İçerik kaynağı hata durumu kaydedilemedi: {Source}", kind);
                }
                return new(false, 0, 0, error);
            }
        }
        finally { gate.Release(); }
    }
}
