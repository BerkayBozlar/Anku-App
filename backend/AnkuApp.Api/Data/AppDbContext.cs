
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

    public DbSet<CampusLocation> CampusLocations
        => Set<CampusLocation>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

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
