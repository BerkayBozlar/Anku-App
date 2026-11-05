
using AnkuApp.Api.Models;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace AnkuApp.Api.Data;

public class AppDbContext : IdentityDbContext<ApplicationUser>
{
    public AppDbContext(DbContextOptions<AppDbContext> options)
        : base(options)
    {
    }

    public DbSet<Club> Clubs => Set<Club>();

    public DbSet<Event> Events => Set<Event>();

    public DbSet<Announcement> Announcements => Set<Announcement>();
    public DbSet<MealMenu> MealMenus => Set<MealMenu>();
    public DbSet<ContentSyncState> ContentSyncStates => Set<ContentSyncState>();

    public DbSet<CampusLocation> CampusLocations
        => Set<CampusLocation>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Entity<Announcement>(entity =>
        {
            entity.Property(a => a.Title).HasMaxLength(300).IsRequired();
            entity.Property(a => a.Summary).HasMaxLength(4000);
            entity.Property(a => a.SourceName).HasMaxLength(150).IsRequired();
            entity.Property(a => a.SourceUrl).HasMaxLength(2000).IsRequired();
            entity.Property(a => a.UniqueKey).HasMaxLength(64).IsRequired();
            entity.HasIndex(a => a.UniqueKey).IsUnique();
            entity.HasIndex(a => a.PublishedAt);
        });
        builder.Entity<MealMenu>(entity =>
        {
            entity.Property(m => m.SourceName).HasMaxLength(150).IsRequired();
            entity.Property(m => m.SourceUrl).HasMaxLength(2000).IsRequired();
            entity.HasIndex(m => m.MenuDate).IsUnique();
        });
        builder.Entity<ContentSyncState>(entity =>
        {
            entity.Property(s => s.Id).HasMaxLength(30);
            entity.Property(s => s.LastError).HasMaxLength(1000);
        });

        builder.Entity<Event>(entity =>
        {
            entity.Property(e => e.Title)
                .IsRequired()
                .HasMaxLength(200);

            entity.Property(e => e.Description)
                .HasMaxLength(2000);

            entity.Property(e => e.Status)
                .HasConversion<string>()
                .HasMaxLength(20);

            entity.HasOne(e => e.Club)
                .WithMany(c => c.Events)
                .HasForeignKey(e => e.ClubId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.CampusLocation)
                .WithMany(c => c.Events)
                .HasForeignKey(e => e.CampusLocationId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasIndex(e => e.EventDate);
        });
    }
}
