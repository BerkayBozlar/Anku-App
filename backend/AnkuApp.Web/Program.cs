using AnkuApp.Web.Auth;
using AnkuApp.Web.Services;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.Authorization;

var builder = WebApplication.CreateBuilder(args);

// Portal yalnızca Yönetici ve Kulüp Yetkilisi rollerine açık; aksi belirtilmedikçe her sayfa bunu ister.
var portalPolicy = new AuthorizationPolicyBuilder()
    .RequireAuthenticatedUser()
    .RequireRole(Roles.Yonetici, Roles.KulupYetkilisi)
    .Build();

builder.Services.AddControllersWithViews(options =>
{
    options.Filters.Add(new AuthorizeFilter(portalPolicy));
});

builder.Services
    .AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.Cookie.Name = "AnkuApp.Portal";
        options.Cookie.HttpOnly = true;
        options.LoginPath = "/Account/Login";
        options.LogoutPath = "/Account/Logout";
        options.AccessDeniedPath = "/Account/AccessDenied";
        options.SlidingExpiration = false;
    });

builder.Services.AddAuthorization();

// Giriş ve tüm veriler ortak Web API üzerinden gelir (docs/api-sozlesmesi.md)
var apiBaseUrl = builder.Configuration["Api:BaseUrl"]
    ?? throw new InvalidOperationException("Api:BaseUrl ayarı eksik.");
void ConfigureApi(HttpClient client)
{
    client.BaseAddress = new Uri(apiBaseUrl.TrimEnd('/') + "/");
    client.Timeout = TimeSpan.FromSeconds(10);
}

builder.Services.AddHttpContextAccessor();
builder.Services.AddTransient<AccessTokenHandler>();
builder.Services.AddHttpClient<AuthApiClient>(ConfigureApi);
// Girişten sonraki istekler kullanıcının API token'ıyla gider
builder.Services.AddHttpClient<ClubsApiClient>(ConfigureApi).AddHttpMessageHandler<AccessTokenHandler>();
builder.Services.AddHttpClient<EventsApiClient>(ConfigureApi).AddHttpMessageHandler<AccessTokenHandler>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.MapStaticAssets();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}")
    .WithStaticAssets();


app.Run();
