using System.ComponentModel.DataAnnotations;
using System.Text;
using AnkuApp.Api.Content;
using AnkuApp.Api.Contracts;

namespace AnkuApp.Api.Tests;

public class AcademicCalendarTests
{
    [Theory]
    [InlineData("22 Eylül 2026", "2026-09-22", "2026-09-22")]
    [InlineData("02-17 Ocak 2027", "2027-01-02", "2027-01-17")]
    [InlineData("21 Eylül-31 Aralık 2026", "2026-09-21", "2026-12-31")]
    [InlineData("25 Ocak–02 Şubat 2027", "2027-01-25", "2027-02-02")]
    [InlineData("31 Aralık-02 Ocak 2027", "2026-12-31", "2027-01-02")]
    [InlineData("31 Aralık 2026-02 Ocak 2027", "2026-12-31", "2027-01-02")]
    [InlineData("16 - 22 KASIM 2026", "2026-11-16", "2026-11-22")]
    [InlineData("  29   Şubat  2028  ", "2028-02-29", "2028-02-29")]
    public void Turkish_date_ranges_keep_both_inclusive_days(string input, string start, string end)
    {
        var actual = AcademicCalendarRules.ParseDates(input);
        Assert.Equal(DateOnly.Parse(start), actual.Start);
        Assert.Equal(DateOnly.Parse(end), actual.End);
    }

    [Theory]
    [InlineData("31 Şubat 2027")]
    [InlineData("29 Şubat 2027")]
    [InlineData("20-10 Eylül 2026")]
    [InlineData("15 Eylül")]
    [InlineData("01 Unknown 2027")]
    [InlineData("Henüz açıklanmadı")]
    [InlineData("1-2-3 Ocak 2027")]
    public void Unknown_or_invalid_dates_are_not_guessed(string input) =>
        Assert.Throws<InvalidDataException>(() => AcademicCalendarRules.ParseDates(input));

    [Theory]
    [InlineData("2026-2027", true)]
    [InlineData("2099-2100", true)]
    [InlineData("2026-2028", false)]
    [InlineData("2026/2027", false)]
    [InlineData("1999-2000", false)]
    [InlineData("", false)]
    public void Academic_year_must_be_two_consecutive_years(string input, bool expected) =>
        Assert.Equal(expected, AcademicCalendarRules.TryYear(input, out _));

    [Fact]
    public void Current_academic_year_uses_Turkey_and_the_August_boundary()
    {
        Assert.Equal("2025-2026", AcademicCalendarRules.CurrentYear(new(2026, 7, 31, 20, 59, 0, TimeSpan.Zero)));
        Assert.Equal("2026-2027", AcademicCalendarRules.CurrentYear(new(2026, 7, 31, 21, 0, 0, TimeSpan.Zero)));
        Assert.Equal("2026-2027", AcademicCalendarRules.CurrentYear(new(2027, 1, 15, 0, 0, 0, TimeSpan.Zero)));
    }

    [Fact]
    public void Repeated_approval_rows_have_different_keys_and_whitespace_is_normalized()
    {
        var first = AcademicCalendarRules.Key("2026-2027", "Genel", "Fall", "Danışman Onayı", "1");
        Assert.NotEqual(first, AcademicCalendarRules.Key("2026-2027", "Genel", "Fall", "Danışman Onayı", "2"));
        Assert.Equal(first, AcademicCalendarRules.Key("2026-2027", "Genel", "Fall", "  Danışman   Onayı ", "1"));
        Assert.NotEqual(first, AcademicCalendarRules.Key("2026-2027", "Genel", "Spring", "Danışman Onayı", "1"));
    }

    [Theory]
    [InlineData("<html>Geçici hata</html>")]
    [InlineData("%PDF-bozuk")]
    [InlineData("")]
    public void Parser_rejects_non_calendar_documents(string value) =>
        Assert.Throws<InvalidDataException>(() => AcademicCalendarParser.Read(Encoding.UTF8.GetBytes(value)));

    private static AcademicCalendarRequest Valid() => new()
    {
        AcademicYear = "2026-2027", Term = "Fall", Title = "Örnek kayıt",
        StartDate = new(2026, 9, 14), EndDate = new(2026, 9, 20),
        SourceUrl = "https://oidb.ankara.edu.tr/", SourcePage = 1
    };

    [Fact]
    public void Manual_calendar_accepts_a_single_day()
    {
        var request = Valid(); request.EndDate = request.StartDate;
        Assert.True(Validator.TryValidateObject(request, new(request), [], true));
    }

    [Theory]
    [InlineData("range")]
    [InlineData("year")]
    [InlineData("term")]
    [InlineData("missing-date")]
    [InlineData("outside-year")]
    [InlineData("source")]
    [InlineData("page")]
    public void Manual_calendar_rejects_invalid_fields(string field)
    {
        var request = Valid();
        switch (field)
        {
            case "range": request.EndDate = request.StartDate!.Value.AddDays(-1); break;
            case "year": request.AcademicYear = "2026-2028"; break;
            case "term": request.Term = "Unknown"; break;
            case "missing-date": request.StartDate = null; break;
            case "outside-year": request.EndDate = new(2028, 1, 1); break;
            case "source": request.SourceUrl = "https://ankara.edu.tr.evil.test/"; break;
            case "page": request.SourcePage = 0; break;
        }
        Assert.False(Validator.TryValidateObject(request, new(request), [], true));
    }
}
