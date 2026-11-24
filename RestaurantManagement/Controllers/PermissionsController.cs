using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;
using RestaurantManagement.Services;

namespace RestaurantManagement.Controllers;

/// <summary>Only the Administrator can give or take away permissions. Administrators always have full access.</summary>
[Authorize(Roles = "Admin")]
public class PermissionsController : Controller
{
    private readonly AppDbContext _db;
    public PermissionsController(AppDbContext db) => _db = db;

    public async Task<IActionResult> Index()
    {
        var users = await _db.Users.Include(u => u.Role).OrderBy(u => u.UserName).ToListAsync();
        ViewBag.Counts = await _db.UserPermissions.Where(p => p.CanView).GroupBy(p => p.UserId)
            .Select(g => new { g.Key, C = g.Count() }).ToDictionaryAsync(x => x.Key, x => x.C);
        return View(users);
    }

    public async Task<IActionResult> Edit(int id)
    {
        var u = await _db.Users.Include(x => x.Role).FirstOrDefaultAsync(x => x.UserId == id);
        if (u == null) return NotFound();
        ViewBag.Perms = await _db.UserPermissions.Where(p => p.UserId == id).ToDictionaryAsync(p => p.ModuleKey, StringComparer.OrdinalIgnoreCase);
        return View(u);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, IFormCollection form)
    {
        var u = await _db.Users.FindAsync(id);
        if (u == null) return NotFound();
        var existing = await _db.UserPermissions.Where(p => p.UserId == id).ToListAsync();
        foreach (var m in ModuleCatalog.All)
        {
            bool On(string r) => form[$"{m.Key}.{r}"].Any(v => v == "true");
            var p = existing.FirstOrDefault(x => string.Equals(x.ModuleKey, m.Key, StringComparison.OrdinalIgnoreCase));
            if (p == null) { p = new UserPermission { UserId = id, ModuleKey = m.Key }; _db.UserPermissions.Add(p); }
            p.CanAdd = On("add"); p.CanEdit = On("edit"); p.CanDelete = On("delete");
            p.CanView = On("view") || p.CanAdd || p.CanEdit || p.CanDelete; // any right implies view
        }
        await _db.SaveChangesAsync();
        TempData["Success"] = $"Permissions saved for {u.UserName}. They apply on the user's next page load.";
        return RedirectToAction(nameof(Edit), new { id });
    }

    /// <summary>Reset a user's permissions to the defaults of the user's role.</summary>
    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> ApplyRoleDefaults(int id)
    {
        var u = await _db.Users.Include(x => x.Role).FirstOrDefaultAsync(x => x.UserId == id);
        if (u == null) return NotFound();
        await ResetToRole(_db, u.UserId, u.Role?.RoleName ?? "");
        TempData["Success"] = $"Permissions reset to the {u.Role?.RoleName} defaults.";
        return RedirectToAction(nameof(Edit), new { id });
    }

    public static async Task ResetToRole(AppDbContext db, int userId, string role)
    {
        db.UserPermissions.RemoveRange(await db.UserPermissions.Where(p => p.UserId == userId).ToListAsync());
        db.UserPermissions.AddRange(ModuleCatalog.RoleDefaults(role, userId));
        await db.SaveChangesAsync();
    }
}
