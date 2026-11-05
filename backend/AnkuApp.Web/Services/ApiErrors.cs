using System.Text.Json;

namespace AnkuApp.Web.Services;

/// <summary>
/// API'nin hata gövdelerini okur: ProblemDetails (<c>detail</c>, <c>errors</c>),
/// API'nin kendi <c>{ "message": ... }</c> gövdesi ya da düz metin.
/// </summary>
public static class ApiErrors
{
    public static async Task<(string? Message, IReadOnlyDictionary<string, string[]>? Errors)> ReadAsync(
        HttpResponseMessage response, CancellationToken ct)
    {
        string text;
        try
        {
            text = await response.Content.ReadAsStringAsync(ct);
        }
        catch (HttpRequestException)
        {
            return (null, null);
        }

        if (string.IsNullOrWhiteSpace(text))
        {
            return (null, null);
        }

        try
        {
            using var doc = JsonDocument.Parse(text);
            var root = doc.RootElement;
            if (root.ValueKind == JsonValueKind.String)
            {
                return (root.GetString(), null);
            }

            if (root.ValueKind != JsonValueKind.Object)
            {
                return (null, null);
            }

            return (ReadMessage(root), ReadErrors(root));
        }
        catch (JsonException)
        {
            // API bazı hatalarda düz metin döndürür
            return (text.Length <= 300 ? text.Trim() : null, null);
        }
    }

    private static string? ReadMessage(JsonElement root)
    {
        // ProblemDetails "detail", API'nin kendi hata gövdeleri "message" kullanır
        foreach (var name in (string[])["detail", "message"])
        {
            if (root.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String)
            {
                return value.GetString();
            }
        }

        return null;
    }

    private static Dictionary<string, string[]>? ReadErrors(JsonElement root)
    {
        if (!root.TryGetProperty("errors", out var errors) || errors.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        var result = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);
        foreach (var field in errors.EnumerateObject())
        {
            if (field.Value.ValueKind != JsonValueKind.Array)
            {
                continue;
            }

            result[field.Name] = field.Value.EnumerateArray()
                .Where(e => e.ValueKind == JsonValueKind.String)
                .Select(e => e.GetString()!)
                .ToArray();
        }

        return result;
    }
}
