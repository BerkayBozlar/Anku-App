namespace AnkuApp.Web.Services;

public enum ApiStatus
{
    Success,
    /// <summary>Token yok ya da süresi dolmuş; oturum kapatılmalı.</summary>
    Unauthorized,
    Forbidden,
    NotFound,
    /// <summary>400: doğrulama hataları <see cref="ApiResult.Errors"/> içinde.</summary>
    Invalid,
    Conflict,
    /// <summary>API'ye ulaşılamadı ya da beklenmeyen bir yanıt geldi.</summary>
    Failed
}

public record ApiResult(
    ApiStatus Status,
    string? Message = null,
    IReadOnlyDictionary<string, string[]>? Errors = null)
{
    public bool IsSuccess => Status == ApiStatus.Success;

    public static ApiResult Ok() => new(ApiStatus.Success);
}

public record ApiResult<T>(
    ApiStatus Status,
    T? Value = default,
    string? Message = null,
    IReadOnlyDictionary<string, string[]>? Errors = null)
    : ApiResult(Status, Message, Errors)
{
    public static ApiResult<T> Ok(T value) => new(ApiStatus.Success, value);

    public static ApiResult<T> From(ApiResult failure) =>
        new(failure.Status, default, failure.Message, failure.Errors);
}
