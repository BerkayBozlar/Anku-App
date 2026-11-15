using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace AnkuApp.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddAcademicCalendar : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AcademicCalendarEntries",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    AcademicYear = table.Column<string>(type: "character varying(9)", maxLength: 9, nullable: false),
                    Scope = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Term = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    Title = table.Column<string>(type: "character varying(400)", maxLength: 400, nullable: false),
                    Description = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    StartDate = table.Column<DateOnly>(type: "date", nullable: false),
                    EndDate = table.Column<DateOnly>(type: "date", nullable: false),
                    SourceName = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    SourceUrl = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: false),
                    SourcePage = table.Column<int>(type: "integer", nullable: true),
                    UniqueKey = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    RetrievedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    IsManual = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AcademicCalendarEntries", x => x.Id);
                    table.CheckConstraint("CK_AcademicCalendarEntries_DateRange", "\"EndDate\" >= \"StartDate\"");
                });

            migrationBuilder.CreateIndex(
                name: "IX_AcademicCalendarEntries_AcademicYear_Scope_Term_Title_Start~",
                table: "AcademicCalendarEntries",
                columns: new[] { "AcademicYear", "Scope", "Term", "Title", "StartDate", "EndDate" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_AcademicCalendarEntries_AcademicYear_StartDate",
                table: "AcademicCalendarEntries",
                columns: new[] { "AcademicYear", "StartDate" });

            migrationBuilder.CreateIndex(
                name: "IX_AcademicCalendarEntries_UniqueKey",
                table: "AcademicCalendarEntries",
                column: "UniqueKey",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AcademicCalendarEntries");
        }
    }
}
