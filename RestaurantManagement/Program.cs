using System.Globalization;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Localization;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews(o => o.Filters.Add<PermissionFilter>());
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<PermissionService>();
builder.Services.AddHttpClient("images", c =>
{
    c.Timeout = TimeSpan.FromSeconds(40);
    c.DefaultRequestHeaders.UserAgent.ParseAdd("RestaurantManagement/1.0 (menu image fetcher)");
});

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services
    .AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Account/Login";
        options.AccessDeniedPath = "/Account/AccessDenied";
        options.ExpireTimeSpan = TimeSpan.FromHours(10);
        options.SlidingExpiration = true;
    });

// Every page requires login unless marked [AllowAnonymous].
builder.Services.AddAuthorization(options =>
{
    options.FallbackPolicy = new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build();
});

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

// Invariant culture keeps decimal / date parsing predictable (1234.50, 2026-11-12).
var culture = CultureInfo.InvariantCulture;
app.UseRequestLocalization(new RequestLocalizationOptions
{
    DefaultRequestCulture = new RequestCulture(culture),
    SupportedCultures = new List<CultureInfo> { culture },
    SupportedUICultures = new List<CultureInfo> { culture }
});

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
