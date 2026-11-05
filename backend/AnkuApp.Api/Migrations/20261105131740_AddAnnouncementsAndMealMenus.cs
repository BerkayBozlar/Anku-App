using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace AnkuApp.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddAnnouncementsAndMealMenus : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Announcements",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    Title = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    Summary = table.Column<string>(type: "character varying(4000)", maxLength: 4000, nullable: true),
                    SourceName = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    SourceUrl = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: false),
                    UniqueKey = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    PublishedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    RetrievedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    IsManual = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Announcements", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ContentSyncStates",
                columns: table => new
                {
                    Id = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    LastAttemptAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    LastSuccessAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    LastError = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ContentSyncStates", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "MealMenus",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    MenuDate = table.Column<DateOnly>(type: "date", nullable: false),
                    Dishes = table.Column<string[]>(type: "text[]", nullable: false),
                    TotalCalories = table.Column<int>(type: "integer", nullable: true),
                    SourceName = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    SourceUrl = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: false),
                    RetrievedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    IsManual = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MealMenus", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Announcements_PublishedAt",
                table: "Announcements",
                column: "PublishedAt");

            migrationBuilder.CreateIndex(
                name: "IX_Announcements_UniqueKey",
                table: "Announcements",
                column: "UniqueKey",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_MealMenus_MenuDate",
                table: "MealMenus",
                column: "MenuDate",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Announcements");

            migrationBuilder.DropTable(
                name: "ContentSyncStates");

            migrationBuilder.DropTable(
                name: "MealMenus");
        }
    }
}
