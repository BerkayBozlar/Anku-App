using System.Globalization;
using System.IO.Compression;
using System.Net;
using System.Text.RegularExpressions;
using System.Xml;
using System.Xml.Linq;

namespace AnkuApp.Api.Content;

public record ImportedAnnouncement(string Title, string? Summary, string SourceUrl, DateTime PublishedAt);
public record ImportedMealMenu(DateOnly MenuDate, string[] Dishes, int? TotalCalories);

public static class OfficialContentParser
{
    private static XDocument ReadXml(Stream input)
    {
        using var reader = XmlReader.Create(input, new XmlReaderSettings
        {
            DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null, MaxCharactersInDocument = 4_000_000
        });
        return XDocument.Load(reader);
    }

    public static IReadOnlyList<ImportedAnnouncement> Announcements(byte[] bytes)
    {
        using var input = new MemoryStream(bytes);
        var document = ReadXml(input);
        if (document.Root?.Name.LocalName != "rss") throw new InvalidDataException("Kaynak geçerli bir RSS belgesi değil.");
        var items = document.Descendants("item").ToList();
        if (items.Count == 0) throw new InvalidDataException("RSS içinde duyuru bulunamadı; kaynak yapısı değişmiş olabilir.");
        var result = new List<ImportedAnnouncement>();
        foreach (var item in items)
        {
            var title = PlainText((string?)item.Element("title") ?? "");
            var url = ((string?)item.Element("link"))?.Trim() ?? "";
            if (title.Length is 0 or > 300 || !ContentSources.IsOfficialUrl(url) ||
                !DateTimeOffset.TryParse((string?)item.Element("pubDate"), CultureInfo.InvariantCulture,
                    DateTimeStyles.AllowWhiteSpaces, out var published))
                throw new InvalidDataException("RSS duyurusunun başlık, bağlantı veya tarihi geçersiz.");
            var summary = PlainText((string?)item.Element("description") ?? "");
            result.Add(new(title, summary.Length > 4000 ? summary[..4000] : summary,
                ContentSources.NormalizeUrl(url), published.UtcDateTime));
        }
        return result.DistinctBy(a => ContentSources.UniqueKey(a.SourceUrl)).ToList();
    }

    private static string PlainText(string html) => Regex.Replace(
        WebUtility.HtmlDecode(Regex.Replace(html, "<[^>]*>", " ", RegexOptions.None, TimeSpan.FromSeconds(1))),
        @"\s+", " ", RegexOptions.None, TimeSpan.FromSeconds(1)).Trim();

    public static IReadOnlyList<ImportedMealMenu> MealMenus(byte[] bytes)
    {
        using var input = new MemoryStream(bytes);
        using var archive = new ZipArchive(input, ZipArchiveMode.Read);
        XDocument Part(string path)
        {
            var entry = archive.GetEntry(path) ?? throw new InvalidDataException("Menü çalışma kitabının yapısı değişmiş.");
            if (entry.Length > 4_000_000) throw new InvalidDataException("Menü XML boyutu sınırı aşıldı.");
            using var stream = entry.Open();
            return ReadXml(stream);
        }
        XNamespace ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
        XNamespace rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
        var workbook = Part("xl/workbook.xml");
        var sheet = workbook.Descendants(ns + "sheet").FirstOrDefault()
            ?? throw new InvalidDataException("Menü sayfası bulunamadı.");
        var relationship = Part("xl/_rels/workbook.xml.rels").Root?.Elements()
            .SingleOrDefault(e => (string?)e.Attribute("Id") == (string?)sheet.Attribute(rel + "id"));
        var target = (string?)relationship?.Attribute("Target") ?? "";
        // Arşivden dosya çıkartılmaz. Yalnızca çalışma kitabının kendi worksheet parçası okunur.
        var sheetPath = target.StartsWith('/') ? target.TrimStart('/') : "xl/" + target;
        if (!sheetPath.StartsWith("xl/worksheets/", StringComparison.Ordinal) || sheetPath.Contains(".."))
            throw new InvalidDataException("Menü sayfa bağlantısı geçersiz.");
        var strings = archive.GetEntry("xl/sharedStrings.xml") is null ? [] :
            Part("xl/sharedStrings.xml").Descendants(ns + "si")
                .Select(si => string.Concat(si.Descendants(ns + "t").Select(t => t.Value))).ToArray();
        string Text(XElement? cell)
        {
            if (cell is null) return "";
            var value = (string?)cell.Element(ns + "v") ?? "";
            return (string?)cell.Attribute("t") switch
            {
                "s" => int.TryParse(value, out var i) && i >= 0 && i < strings.Length
                    ? strings[i].Trim() : throw new InvalidDataException("Menü metin hücresi çözümlenemedi."),
                "e" => throw new InvalidDataException("Menü hücresinde hesaplama hatası var."),
                "inlineStr" => string.Concat(cell.Descendants(ns + "t").Select(t => t.Value)).Trim(),
                _ => value.Trim()
            };
        }
        var date1904 = (string?)workbook.Root?.Element(ns + "workbookPr")?.Attribute("date1904") is "1" or "true";
        var result = new List<ImportedMealMenu>();
        foreach (var row in Part(sheetPath).Descendants(ns + "row"))
        {
            XElement? Cell(string col) => row.Elements(ns + "c").FirstOrDefault(c =>
                Regex.Replace((string?)c.Attribute("r") ?? "", "[0-9]", "") == col);
            if (!double.TryParse(Text(Cell("A")), NumberStyles.Float, CultureInfo.InvariantCulture, out var serial) ||
                serial < 1 || serial > 73050) continue;
            var date = DateOnly.FromDateTime(DateTime.FromOADate(serial + (date1904 ? 1462 : 0)));
            if (date.Year < 2000 || date.Year > 2100) continue;
            var dishes = new[] { "B", "C", "D", "E" }.Select(col => Text(Cell(col))).ToArray();
            if (dishes.Any(d => string.IsNullOrWhiteSpace(d) || d.Length > 300))
                throw new InvalidDataException("Tarihli menü satırında dört yemek bulunamadı; kaynak değişmiş olabilir.");
            var calorieMatch = Regex.Match(Text(Cell("F")), @"^\s*(\d{1,5})\s*(?:KKAL|KCAL)?\s*$", RegexOptions.IgnoreCase);
            int? calories = calorieMatch.Success ? int.Parse(calorieMatch.Groups[1].Value, CultureInfo.InvariantCulture) : null;
            result.Add(new(date, dishes, calories));
        }
        if (result.Count == 0 || result.Select(m => m.MenuDate).Distinct().Count() != result.Count)
            throw new InvalidDataException("Tarihli menü bulunamadı veya yinelenen tarihler var.");
        return result.OrderBy(m => m.MenuDate).ToList();
    }
}
