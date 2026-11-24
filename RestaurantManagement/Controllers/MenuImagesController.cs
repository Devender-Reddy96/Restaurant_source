using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Controllers;

/// <summary>Downloads a photo for every menu item from Wikipedia / Wikimedia Commons, right inside the application.
/// Files go to wwwroot/uploads/menu/&lt;Title&gt;.jpg - the same paths written by 04_Phase3_Update.sql.</summary>
[Authorize]
public class MenuImagesController : Controller
{
    private readonly AppDbContext _db;
    private readonly IWebHostEnvironment _env;
    private readonly IHttpClientFactory _http;
    private const string WebFolder = "/uploads/menu";

    public MenuImagesController(AppDbContext db, IWebHostEnvironment env, IHttpClientFactory http)
    { _db = db; _env = env; _http = http; }

    public async Task<IActionResult> Index()
    {
        var items = await _db.FoodItems.Include(f => f.Category).OrderBy(f => f.Category!.DisplayOrder).ThenBy(f => f.FoodName).ToListAsync();
        ViewBag.Exists = items.ToDictionary(f => f.FoodItemId, f => FileExists(f.ImagePath));
        return View(items);
    }

    /// <summary>Saves the Wikipedia page title used as the photo source (blank = use the food name).</summary>
    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> SetSource(int id, string? source)
    {
        var f = await _db.FoodItems.FindAsync(id);
        if (f == null) return Json(new { ok = false, message = "Item not found." });
        f.ImageSource = string.IsNullOrWhiteSpace(source) ? null : source.Trim()[..Math.Min(200, source.Trim().Length)];
        await _db.SaveChangesAsync();
        return Json(new { ok = true });
    }

    /// <summary>Download (or re-download) the photo of one item.</summary>
    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> FetchOne(int id)
    {
        var f = await _db.FoodItems.FindAsync(id);
        if (f == null) return Json(new { ok = false, message = "Item not found." });
        var (ok, msg) = await Download(f, force: true);
        await _db.SaveChangesAsync();
        return Json(new { ok, message = msg, path = f.ImagePath });
    }

    /// <summary>Downloads the next batch of items whose photo file is missing. The page calls this repeatedly until remaining = 0.</summary>
    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> FetchMissing(int skip = 0, int take = 8)
    {
        take = Math.Clamp(take, 1, 20);
        var all = await _db.FoodItems.OrderBy(f => f.FoodItemId).ToListAsync();
        var missing = all.Where(f => !FileExists(f.ImagePath)).ToList();
        var batch = missing.Skip(skip).Take(take).ToList();
        var done = new List<object>();
        int failed = 0;
        foreach (var f in batch)
        {
            var (ok, msg) = await Download(f, force: false);
            if (!ok) failed++;
            done.Add(new { id = f.FoodItemId, ok, message = msg, path = f.ImagePath });
        }
        await _db.SaveChangesAsync();
        // items that failed stay "missing", so the next call skips past them
        return Json(new { ok = true, items = done, failed, nextSkip = skip + failed, remaining = Math.Max(0, missing.Count - skip - batch.Count) });
    }

    private bool FileExists(string? webPath)
    {
        if (string.IsNullOrWhiteSpace(webPath) || webPath.StartsWith("http", StringComparison.OrdinalIgnoreCase)) return false;
        var full = Path.Combine(_env.WebRootPath, webPath.TrimStart('/').Replace('/', Path.DirectorySeparatorChar));
        return System.IO.File.Exists(full);
    }

    public static string SafeName(string title) => Regex.Replace(title, "[^A-Za-z0-9]+", "_").Trim('_');

    private async Task<(bool ok, string message)> Download(FoodItem f, bool force)
    {
        var title = string.IsNullOrWhiteSpace(f.ImageSource) ? Regex.Replace(f.FoodName, @"\s*\(.*?\)", "").Trim() : f.ImageSource.Trim();
        var safe = SafeName(title);
        if (safe.Length == 0) return (false, "No image source title.");
        var webPath = $"{WebFolder}/{safe}.jpg";
        var dir = Path.Combine(_env.WebRootPath, "uploads", "menu");
        Directory.CreateDirectory(dir);
        var full = Path.Combine(dir, safe + ".jpg");

        if (System.IO.File.Exists(full) && !force)
        {
            f.ImagePath = webPath; f.ImageSource ??= title;
            return (true, "Already downloaded (shared photo).");
        }
        try
        {
            var http = _http.CreateClient("images");
            var api = "https://en.wikipedia.org/api/rest_v1/page/summary/" + Uri.EscapeDataString(title.Replace(' ', '_'));
            using var res = await http.GetAsync(api);
            if (!res.IsSuccessStatusCode) return (false, $"Wikipedia page '{title}' not found ({(int)res.StatusCode}).");
            using var doc = JsonDocument.Parse(await res.Content.ReadAsStringAsync());
            string? src = null;
            if (doc.RootElement.TryGetProperty("thumbnail", out var th) && th.TryGetProperty("source", out var s1)) src = s1.GetString();
            else if (doc.RootElement.TryGetProperty("originalimage", out var oi) && oi.TryGetProperty("source", out var s2)) src = s2.GetString();
            if (string.IsNullOrEmpty(src)) return (false, $"'{title}' has no photo on Wikipedia.");
            src = Regex.Replace(src, @"/\d+px-", "/500px-");

            var bytes = await http.GetByteArrayAsync(src);
            if (bytes.Length < 500) return (false, "Downloaded file is too small.");
            await System.IO.File.WriteAllBytesAsync(full, bytes);
            f.ImagePath = webPath; f.ImageSource ??= title;
            return (true, "Downloaded.");
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException or IOException)
        {
            return (false, "Could not download: " + ex.Message);
        }
    }
}
