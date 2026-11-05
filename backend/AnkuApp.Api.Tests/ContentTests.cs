using System.ComponentModel.DataAnnotations;
using System.IO.Compression;
using System.Net;
using System.Text;
using AnkuApp.Api.Content;
using AnkuApp.Api.Contracts;

namespace AnkuApp.Api.Tests;

public class ContentTests
{
    private const string Url = "https://oidb.ankara.edu.tr/2026/11/05/duyuru/";
    private static byte[] Rss(string item) => Encoding.UTF8.GetBytes($"<rss version='2.0'><channel>{item}</channel></rss>");
    private const string Item = "<item><title>Öğrenci &amp; Kampüs</title><link>https://oidb.ankara.edu.tr/2026/11/05/duyuru/</link><pubDate>Thu, 05 Nov 2026 10:00:00 +0000</pubDate><description><![CDATA[<p>Yeni <b>duyuru</b>.</p>]]></description></item>";

    [Fact]
    public void Rss_preserves_Turkish_text_UTC_and_plain_summary()
    {
        var item = Assert.Single(OfficialContentParser.Announcements(Rss(Item)));
        Assert.Equal("Öğrenci & Kampüs", item.Title);
        Assert.Equal("Yeni duyuru .", item.Summary);
        Assert.Equal(DateTimeKind.Utc, item.PublishedAt.Kind);
        Assert.Equal(new DateTime(2026, 11, 5, 10, 0, 0, DateTimeKind.Utc), item.PublishedAt);
    }

    [Fact] public void Rss_duplicates_are_collapsed() => Assert.Single(OfficialContentParser.Announcements(Rss(Item + Item)));
    [Fact] public void Rss_empty_source_is_a_failure() => Assert.Throws<InvalidDataException>(() => OfficialContentParser.Announcements(Rss("")));
    [Theory]
    [InlineData("<html>maintenance</html>")]
    [InlineData("<!DOCTYPE rss [<!ENTITY x SYSTEM 'file:///C:/Windows/win.ini'>]><rss>&x;</rss>")]
    public void Rss_rejects_HTML_or_DTD(string content) => Assert.ThrowsAny<Exception>(() => OfficialContentParser.Announcements(Encoding.UTF8.GetBytes(content)));
    [Fact]
    public void Rss_bad_item_does_not_allow_partial_import() => Assert.Throws<InvalidDataException>(() =>
        OfficialContentParser.Announcements(Rss(Item + Item.Replace("+0000", "invalid"))));

    [Theory]
    [InlineData("javascript:alert(1)")]
    [InlineData("https://ankara.edu.tr.example.com/path")]
    [InlineData("https://ankara.edu.tr@evil.test/path")]
    [InlineData("http://localhost:5080/api/health")]
    [InlineData("https://sks.ankara.edu.tr:444/path")]
    public void Untrusted_source_links_are_rejected(string url) => Assert.False(ContentSources.IsOfficialUrl(url));

    [Fact]
    public void Unique_key_ignores_fragment_and_trailing_slash() => Assert.Equal(ContentSources.UniqueKey(Url), ContentSources.UniqueKey(Url.TrimEnd('/') + "#details"));

    [Fact]
    public void Daily_schedule_uses_Turkey_midnight_and_persisted_attempt()
    {
        var now = new DateTimeOffset(2026, 11, 5, 21, 5, 0, TimeSpan.Zero); // 6 Kasım 00:05
        Assert.True(ContentSyncService.IsDue(new DateTime(2026, 11, 5, 20, 59, 0, DateTimeKind.Utc), now));
        Assert.False(ContentSyncService.IsDue(new DateTime(2026, 11, 5, 21, 1, 0, DateTimeKind.Utc), now));
        Assert.True(ContentSyncService.IsDue(null, now));
    }

    private static byte[] Workbook(string row, bool date1904 = false)
    {
        using var output = new MemoryStream();
        using (var zip = new ZipArchive(output, ZipArchiveMode.Create, true))
        {
            void Part(string name, string xml)
            {
                using var writer = new StreamWriter(zip.CreateEntry(name).Open(), Encoding.UTF8);
                writer.Write(xml);
            }
            Part("xl/workbook.xml", $"<workbook xmlns='http://schemas.openxmlformats.org/spreadsheetml/2006/main' xmlns:r='http://schemas.openxmlformats.org/officeDocument/2006/relationships'><workbookPr date1904='{(date1904 ? 1 : 0)}'/><sheets><sheet name='Menü' sheetId='1' r:id='rId1'/></sheets></workbook>");
            Part("xl/_rels/workbook.xml.rels", "<Relationships><Relationship Id='rId1' Target='worksheets/sheet1.xml'/></Relationships>");
            Part("xl/sharedStrings.xml", "<sst xmlns='http://schemas.openxmlformats.org/spreadsheetml/2006/main'><si><t>Mercimek Çorbası</t></si></sst>");
            Part("xl/worksheets/sheet1.xml", $"<worksheet xmlns='http://schemas.openxmlformats.org/spreadsheetml/2006/main'><sheetData>{row}</sheetData></worksheet>");
        }
        return output.ToArray();
    }

    private const string Row = "<row r='5'><c r='A5'><v>46331</v></c><c r='B5' t='s'><v>0</v></c><c r='C5' t='inlineStr'><is><t>Örnek Ana Yemek</t></is></c><c r='D5' t='inlineStr'><is><t>Pilav</t></is></c><c r='E5' t='inlineStr'><is><t>Yoğurt</t></is></c><c r='F5' t='inlineStr'><is><t>1200 KKAL</t></is></c></row>";

    [Fact]
    public void Menu_reads_serial_dates_shared_strings_and_inline_strings()
    {
        var menu = Assert.Single(OfficialContentParser.MealMenus(Workbook(Row)));
        Assert.Equal(new DateOnly(2026, 11, 5), menu.MenuDate);
        Assert.Equal("Mercimek Çorbası", menu.Dishes[0]);
        Assert.Equal("Örnek Ana Yemek", menu.Dishes[1]);
        Assert.Equal(1200, menu.TotalCalories);
    }

    [Fact]
    public void Menu_supports_1904_date_system()
    {
        var menu = Assert.Single(OfficialContentParser.MealMenus(Workbook(Row.Replace("46331", "44869"), true)));
        Assert.Equal(new DateOnly(2026, 11, 5), menu.MenuDate);
    }

    [Fact] public void Menu_empty_structure_is_a_failure() => Assert.Throws<InvalidDataException>(() => OfficialContentParser.MealMenus(Workbook("")));
    [Fact] public void Menu_duplicate_dates_are_a_failure() => Assert.Throws<InvalidDataException>(() => OfficialContentParser.MealMenus(Workbook(Row + Row)));
    [Fact] public void Menu_partial_row_is_a_failure() => Assert.Throws<InvalidDataException>(() => OfficialContentParser.MealMenus(Workbook(Row.Replace("Yoğurt", " "))));
    [Fact] public void Menu_non_zip_is_a_failure() => Assert.Throws<InvalidDataException>(() => OfficialContentParser.MealMenus(Encoding.UTF8.GetBytes("<html>Down</html>")));
    [Fact] public void Menu_broken_shared_string_is_a_failure() => Assert.Throws<InvalidDataException>(() => OfficialContentParser.MealMenus(Workbook(Row.Replace("<v>0</v>", "<v>999</v>"))));

    [Fact]
    public void Manual_menu_rejects_blank_dishes()
    {
        var request = new MealMenuRequest { MenuDate = new(2026, 11, 5), Dishes = [" "], SourceUrl = Url };
        var errors = new List<ValidationResult>();
        Assert.False(Validator.TryValidateObject(request, new ValidationContext(request), errors, true));
        Assert.Contains(errors, e => e.MemberNames.Contains("Dishes"));
    }

    [Fact]
    public async Task Downloader_rejects_redirect_outside_university()
    {
        using var handler = new StubHandler(_ => new HttpResponseMessage(HttpStatusCode.Found)
        { Headers = { Location = new Uri("http://127.0.0.1/private") } });
        using var http = new HttpClient(handler);
        await Assert.ThrowsAsync<InvalidDataException>(() => new OfficialContentClient(http).DownloadAsync(Url, default));
        Assert.Equal(1, handler.Calls);
    }

    [Fact]
    public async Task Downloader_bounds_response_size()
    {
        using var handler = new StubHandler(_ => new HttpResponseMessage(HttpStatusCode.OK)
        { Content = new ByteArrayContent(new byte[8 * 1024 * 1024 + 1]) });
        using var http = new HttpClient(handler);
        await Assert.ThrowsAsync<InvalidDataException>(() => new OfficialContentClient(http).DownloadAsync(Url, default));
    }

    private sealed class StubHandler(Func<HttpRequestMessage, HttpResponseMessage> reply) : HttpMessageHandler
    {
        public int Calls { get; private set; }
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        { Calls++; return Task.FromResult(reply(request)); }
    }
}
