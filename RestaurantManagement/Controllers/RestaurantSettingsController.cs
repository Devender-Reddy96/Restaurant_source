using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Controllers;

[Authorize]
public class RestaurantSettingsController : Controller
{
    private readonly AppDbContext _db;
    public RestaurantSettingsController(AppDbContext db) => _db = db;

    public async Task<IActionResult> Index()
    {
        var s = await _db.RestaurantSettings.FirstOrDefaultAsync() ?? new RestaurantSetting();
        return View(s);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Index(RestaurantSetting m)
    {
        if (!ModelState.IsValid) return View(m);
        var s = await _db.RestaurantSettings.FirstOrDefaultAsync();
        if (s == null) { s = new RestaurantSetting { RestaurantSettingId = 1 }; _db.RestaurantSettings.Add(s); }
        s.RestaurantName = m.RestaurantName;
        s.OwnerName = m.OwnerName;
        s.OwnerMobile = m.OwnerMobile;
        s.UpiId = m.UpiId?.Trim();
        s.UpiPayeeName = m.UpiPayeeName;
        s.PublicBaseUrl = m.PublicBaseUrl;
        s.BillFooter = m.BillFooter;
        s.UpdatedOn = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        TempData["Success"] = "Settings saved.";
        return RedirectToAction(nameof(Index));
    }
}
