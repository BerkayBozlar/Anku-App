namespace AnkuApp.Api.Content;

public sealed class OfficialContentClient(HttpClient http)
{
    public async Task<byte[]> DownloadAsync(string url, CancellationToken ct)
    {
        // Yönlendirme dahil her adresi kontrol et; istek gövdelerinden URL alınmaz.
        for (var redirects = 0; redirects < 4; redirects++)
        {
            if (!ContentSources.IsOfficialUrl(url))
                throw new InvalidDataException("Kaynak Ankara Üniversitesi alanında olmalıdır.");
            using var response = await http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, ct);
            if ((int)response.StatusCode is >= 300 and < 400 && response.Headers.Location is { } location)
            {
                url = new Uri(new Uri(url), location).AbsoluteUri;
                continue;
            }
            response.EnsureSuccessStatusCode();
            const int maxBytes = 8 * 1024 * 1024;
            if (response.Content.Headers.ContentLength > maxBytes)
                throw new InvalidDataException("Kaynak dosyası boyut sınırını aşıyor.");
            await using var input = await response.Content.ReadAsStreamAsync(ct);
            using var output = new MemoryStream();
            var buffer = new byte[8192];
            int read;
            while ((read = await input.ReadAsync(buffer, ct)) > 0)
            {
                if (output.Length + read > maxBytes) throw new InvalidDataException("Kaynak dosyası boyut sınırını aşıyor.");
                await output.WriteAsync(buffer.AsMemory(0, read), ct);
            }
            return output.ToArray();
        }
        throw new InvalidDataException("Kaynak çok fazla yönlendirme yaptı.");
    }
}
