using AnkuApp.Api.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace AnkuApp.Api.Data;

/// <summary>Yalnızca --seed-demo komutuyla çalışır; mevcut kayıtları güncellemez.</summary>
public static class DemoDataSeeder
{
    public static async Task SeedAsync(IServiceProvider services)
    {
        var users = services.GetRequiredService<UserManager<ApplicationUser>>();
        var accounts = new[]
        {
            (Email: "admin@ankuapp.test", Role: "Yönetici"),
            (Email: "kulup@ankuapp.test", Role: "Kulüp Yetkilisi"),
            (Email: "ogrenci@ankuapp.test", Role: "Öğrenci")
        };

        foreach (var account in accounts)
        {
            var user = await users.FindByEmailAsync(account.Email);
            if (user is null || !await users.IsInRoleAsync(user, account.Role))
            {
                throw new InvalidOperationException(
                    $"Demo hesabı eksik veya rolü yanlış: {account.Email}. " +
                    "Seed:AdminPassword, Seed:ClubPassword ve Seed:StudentPassword yerel ayarlarını kontrol edin.");
            }
        }

        var manager = (await users.FindByEmailAsync("kulup@ankuapp.test"))!;
        var db = services.GetRequiredService<AppDbContext>();
        await using var transaction = await db.Database.BeginTransactionAsync();
        var addedClubs = 0;
        var addedLocations = 0;
        var addedEvents = 0;

        async Task<Club> ClubAsync(string name, string description, string? managerId)
        {
            var club = await db.Clubs.SingleOrDefaultAsync(c => c.Name == name);
            if (club is not null) return club;

            club = new Club { Name = name, Description = description, AuthorizedUserId = managerId };
            db.Clubs.Add(club);
            addedClubs++;
            return club;
        }

        async Task<CampusLocation> LocationAsync(string name)
        {
            var location = await db.CampusLocations.SingleOrDefaultAsync(c => c.Name == name);
            if (location is not null) return location;

            // Bunlar gösterim için temsili alanlardır; gerçek bina/GPS verisi 7. haftanın işidir.
            location = new CampusLocation { Name = name, Campus = "Tandoğan", Type = "Demo alanı" };
            db.CampusLocations.Add(location);
            addedLocations++;
            return location;
        }

        var technology = await ClubAsync("[Demo] Teknoloji Topluluğu",
            "4. hafta gösterimi: yazılım atölyeleri ve öğrenci buluşmaları.", manager.Id);
        var culture = await ClubAsync("[Demo] Kültür ve Sanat Topluluğu",
            "4. hafta gösterimi: konserler ve kültür etkinlikleri. Bu kulübün yetkilisi atanmamıştır.", null);
        var meetingArea = await LocationAsync("[Demo] Tandoğan Buluşma Alanı");
        var eventArea = await LocationAsync("[Demo] Tandoğan Etkinlik Alanı");
        await db.SaveChangesAsync();

        // İlk oluşturma gününe göre tarihler: demo günü de yaklaşan kayıtlar bulunsun.
        var today = DateTime.UtcNow.Date.AddHours(15); // Türkiye saatiyle 18:00
        var examples = new[]
        {
            (Club: technology, Location: meetingArea, Title: "[Demo] Flutter ve API Atölyesi", Days: 14, Status: EventStatus.Published, Capacity: 40),
            (Club: technology, Location: meetingArea, Title: "[Demo] Geçmiş Tanışma Buluşması", Days: -7, Status: EventStatus.Published, Capacity: 60),
            (Club: technology, Location: meetingArea, Title: "[Demo] Hazırlık Aşamasındaki Atölye", Days: 21, Status: EventStatus.Draft, Capacity: 30),
            (Club: technology, Location: meetingArea, Title: "[Demo] İptal Edilen Söyleşi", Days: 16, Status: EventStatus.Cancelled, Capacity: 50),
            (Club: culture, Location: eventArea, Title: "[Demo] Kampüs Konseri", Days: 15, Status: EventStatus.Published, Capacity: 200),
            (Club: culture, Location: eventArea, Title: "[Demo] Geçmiş Kültür Buluşması", Days: -14, Status: EventStatus.Published, Capacity: 80)
        };

        foreach (var example in examples)
        {
            if (await db.Events.AnyAsync(e => e.ClubId == example.Club.Id && e.Title == example.Title)) continue;

            db.Events.Add(new Event
            {
                ClubId = example.Club.Id,
                CampusLocationId = example.Location.Id,
                Title = example.Title,
                Description = "4. hafta için temsili demo etkinliği; gerçek üniversite duyurusu değildir.",
                EventDate = today.AddDays(example.Days),
                Status = example.Status,
                Capacity = example.Capacity
            });
            addedEvents++;
        }

        await db.SaveChangesAsync();
        await transaction.CommitAsync();
        services.GetRequiredService<ILoggerFactory>().CreateLogger("DemoDataSeeder").LogInformation(
            "Demo hazır. Eklenen: {Clubs} kulüp, {Locations} konum, {Events} etkinlik. Mevcut kayıtlar korundu.",
            addedClubs, addedLocations, addedEvents);
    }
}
