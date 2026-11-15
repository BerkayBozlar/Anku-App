using System.Globalization;
using System.Text.RegularExpressions;
using UglyToad.PdfPig;
using UglyToad.PdfPig.Content;
using UglyToad.PdfPig.DocumentLayoutAnalysis.WordExtractor;

namespace AnkuApp.Api.Content;

public record ImportedCalendarEntry(string AcademicYear, string Scope, string Term, string Title,
    DateOnly StartDate, DateOnly EndDate, int SourcePage, string UniqueKey);

public static class AcademicCalendarParser
{
    public static IReadOnlyList<ImportedCalendarEntry> Read(byte[] bytes, CancellationToken ct = default)
    {
        if (bytes.Length is < 5 or > 8 * 1024 * 1024 || !bytes.AsSpan(0, 5).SequenceEqual("%PDF-"u8))
            throw new InvalidDataException("Akademik takvim kaynağı PDF değil veya boyutu geçersiz.");
        try
        {
            using var pdf = PdfDocument.Open(bytes);
            if (pdf.NumberOfPages is < 2 or > 30) throw new InvalidDataException("Akademik takvimin sayfa yapısı değişmiş.");
            var result = new List<ImportedCalendarEntry>();
            string? academicYear = null;
            for (var number = 1; number <= 2; number++)
            {
                ct.ThrowIfCancellationRequested();
                var page = pdf.GetPage(number);
                var words = page.GetWords(NearestNeighbourWordExtractor.Instance)
                    .Where(w => w.TextOrientation == TextOrientation.Horizontal && !string.IsNullOrWhiteSpace(w.Text)).ToArray();
                var header = Join(words.Where(w => w.BoundingBox.Bottom > page.Height * .8));
                var yearMatch = Regex.Match(header, @"20\d{2}-20\d{2}");
                if (!header.Contains("ÖN LİSANS VE LİSANS", StringComparison.Ordinal) ||
                    !header.Contains("ANKARA", StringComparison.Ordinal) ||
                    !AcademicCalendarRules.TryYear(yearMatch.Value, out var year) ||
                    (academicYear is not null && academicYear != yearMatch.Value))
                    throw new InvalidDataException("Genel ön lisans/lisans takvim başlığı doğrulanamadı.");
                academicYear = yearMatch.Value;
                var term = number == 1 ? "Fall" : "Spring";
                // İncelenen iki sütunlu genel takvim: yatay tarih sütunu, solda açıklama.
                // Tıp ve diğer programa özel çok sütunlu sayfalar genel takvimle karıştırılmaz.
                var split = page.Width * .57;
                var lines = new List<List<Word>>();
                foreach (var word in words.Where(w => w.BoundingBox.Left >= split && w.BoundingBox.Bottom < page.Height * .9)
                    .OrderByDescending(w => w.BoundingBox.Bottom))
                {
                    var line = lines.LastOrDefault(l => Math.Abs(l[0].BoundingBox.Bottom - word.BoundingBox.Bottom) < 3);
                    if (line is null) lines.Add([word]); else line.Add(word);
                }
                var occurrences = new Dictionary<string, int>(StringComparer.Ordinal);
                var pageEntries = new List<ImportedCalendarEntry>();
                foreach (var line in lines)
                {
                    ct.ThrowIfCancellationRequested();
                    var dates = Join(line.OrderBy(w => w.BoundingBox.Left));
                    if (!Regex.IsMatch(dates, @"^\d")) continue; // Hazırlık programının henüz açıklanmamış tarihine gün uydurulmaz.
                    var (start, end) = AcademicCalendarRules.ParseDates(dates);
                    if (start.Year < year || end.Year > year + 1) throw new InvalidDataException("Takvim tarihi akademik yılın dışında.");
                    var y = line.Average(w => w.BoundingBox.Bottom);
                    var titleWords = words.Where(w => w.BoundingBox.Left < split && Math.Abs(w.BoundingBox.Bottom - y) < 8)
                        .OrderByDescending(w => Math.Round(w.BoundingBox.Bottom / 3)).ThenBy(w => w.BoundingBox.Left);
                    var title = Join(titleWords).TrimEnd(' ', '*');
                    if (title.Length is < 3 or > 400) throw new InvalidDataException("Takvim satırının başlığı çözümlenemedi.");
                    var occurrence = occurrences.GetValueOrDefault(title) + 1;
                    occurrences[title] = occurrence;
                    var key = AcademicCalendarRules.Key(academicYear, AcademicCalendarRules.GeneralScope, term, title, occurrence.ToString(CultureInfo.InvariantCulture));
                    pageEntries.Add(new(academicYear, AcademicCalendarRules.GeneralScope, term, title, start, end, number, key));
                }
                // İncelenen düzende 30 güz, 25 bahar satırı var. Kısmi okuma eski satırları
                // silmesin: kaynak satır düzeni değişirse otomatik aktarım yerine manuel yedek kullanılır.
                if (pageEntries.Count != (number == 1 ? 30 : 25) ||
                    !pageEntries.Any(e => e.Title == "Derslerin Başlama ve Bitiş Tarihleri") ||
                    !pageEntries.Any(e => e.Title == "Final Sınavı Tarihleri") ||
                    !pageEntries.Any(e => e.Title == "Bütünleme Sınav Tarihleri"))
                    throw new InvalidDataException("Takvim eksik veya satır düzeni değişmiş; mevcut veri korunacak.");
                result.AddRange(pageEntries);
            }
            return result;
        }
        catch (OperationCanceledException) { throw; }
        catch (InvalidDataException) { throw; }
        catch (Exception ex) when (ex is not OutOfMemoryException)
        {
            throw new InvalidDataException("Akademik takvim PDF'si okunamadı.", ex);
        }
    }

    private static string Join(IEnumerable<Word> words) => AcademicCalendarRules.Normalize(string.Join(' ', words.Select(w => w.Text)));
}
