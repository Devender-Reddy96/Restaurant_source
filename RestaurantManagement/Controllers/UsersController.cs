using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models;
using RestaurantManagement.Models.Entities;
using RestaurantManagement.Services;

namespace RestaurantManagement.Controllers;

[Authorize(Roles = "Admin")]
public class UsersController : Controller
{
    private readonly AppDbContext _db;
    public UsersController(AppDbContext db) => _db = db;

    public async Task<IActionResult> Index()
    {
        var list = await _db.Users.Include(u => u.Role).Include(u => u.Branch)
            .OrderBy(u => u.UserName).ToListAsync();
        return View(list);
    }

    public async Task<IActionResult> Create()
    {
        var m = new UserFormViewModel();
        await Lookups(m);
        return View("Form", m);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(UserFormViewModel m)
    {
        if (string.IsNullOrWhiteSpace(m.Password))
            ModelState.AddModelError(nameof(m.Password), "Password is required.");
        if (await _db.Users.AnyAsync(u => u.UserName == m.UserName))
            ModelState.AddModelError(nameof(m.UserName), "This user name is already taken.");

        if (ModelState.IsValid)
        {
            var nu = new AppUser
            {
                UserName = m.UserName.Trim(),
                FullName = m.FullName.Trim(),
                PasswordHash = PasswordHasher.Hash(m.Password!),
                RoleId = m.RoleId!.Value,
                BranchId = m.BranchId,
                IsActive = m.IsActive
            };
            _db.Users.Add(nu);
            await _db.SaveChangesAsync();
            var roleName = await _db.Roles.Where(r => r.RoleId == nu.RoleId).Select(r => r.RoleName).FirstOrDefaultAsync() ?? "";
            await PermissionsController.ResetToRole(_db, nu.UserId, roleName);
            TempData["Success"] = "User created with the default permissions of the role. Adjust them under Permissions.";
            return RedirectToAction(nameof(Index));
        }
        await Lookups(m);
        return View("Form", m);
    }

    public async Task<IActionResult> Edit(int id)
    {
        var u = await _db.Users.FindAsync(id);
        if (u == null) return NotFound();
        var m = new UserFormViewModel
        {
            UserId = u.UserId, UserName = u.UserName, FullName = u.FullName,
            RoleId = u.RoleId, BranchId = u.BranchId, IsActive = u.IsActive
        };
        await Lookups(m);
        return View("Form", m);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, UserFormViewModel m)
    {
        if (id != m.UserId) return BadRequest();
        var u = await _db.Users.FindAsync(id);
        if (u == null) return NotFound();

        if (await _db.Users.AnyAsync(x => x.UserName == m.UserName && x.UserId != id))
            ModelState.AddModelError(nameof(m.UserName), "This user name is already taken.");
        if (u.UserName == User.Identity?.Name && !m.IsActive)
            ModelState.AddModelError(nameof(m.IsActive), "You cannot deactivate your own account.");

        if (ModelState.IsValid)
        {
            u.UserName = m.UserName.Trim();
            u.FullName = m.FullName.Trim();
            u.RoleId = m.RoleId!.Value;
            u.BranchId = m.BranchId;
            u.IsActive = m.IsActive;
            if (!string.IsNullOrWhiteSpace(m.Password)) u.PasswordHash = PasswordHasher.Hash(m.Password);
            await _db.SaveChangesAsync();
            TempData["Success"] = "User updated successfully.";
            return RedirectToAction(nameof(Index));
        }
        await Lookups(m);
        return View("Form", m);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        var u = await _db.Users.FindAsync(id);
        if (u == null) return NotFound();
        if (u.UserName == User.Identity?.Name)
        {
            TempData["Error"] = "You cannot delete your own account.";
            return RedirectToAction(nameof(Index));
        }
        try
        {
            _db.Users.Remove(u);
            await _db.SaveChangesAsync();
            TempData["Success"] = "User deleted.";
        }
        catch (DbUpdateException)
        {
            TempData["Error"] = "This user is already used elsewhere. Mark it inactive instead.";
        }
        return RedirectToAction(nameof(Index));
    }

    private async Task Lookups(UserFormViewModel m)
    {
        ViewBag.RoleList = new SelectList(await _db.Roles.Where(r => r.IsActive).OrderBy(r => r.RoleName).ToListAsync(),
            "RoleId", "RoleName", m.RoleId);
        ViewBag.BranchList = new SelectList(await _db.Branches.Where(b => b.IsActive).OrderBy(b => b.BranchName).ToListAsync(),
            "BranchId", "BranchName", m.BranchId);
    }
}
