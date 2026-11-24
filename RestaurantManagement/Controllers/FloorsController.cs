using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Controllers;

[Authorize]
public class FloorsController : Controller
{
    private readonly AppDbContext _db;

    public FloorsController(AppDbContext db)
    {
        _db = db;

    }

    public async Task<IActionResult> Index()
    {
        var list = await _db.Floors
            .Include(x => x.Branch)
            .OrderBy(x => x.FloorName)
            .ToListAsync();
        return View(list);
    }

    public async Task<IActionResult> Create()
    {
        var m = new Floor();
        await Lookups(m);
        return View("Form", m);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Floor m)
    {

        if (ModelState.IsValid)
        {

            try
            {
                _db.Floors.Add(m);
                await _db.SaveChangesAsync();
                TempData["Success"] = "Floor / Area added successfully.";
                return RedirectToAction(nameof(Index));
            }
            catch (DbUpdateException)
            {
                ModelState.AddModelError("", "Could not save. A record with the same name / code may already exist.");
            }
        }
        await Lookups(m);
        return View("Form", m);
    }

    public async Task<IActionResult> Edit(int id)
    {
        var e = await _db.Floors.FindAsync(id);
        if (e == null) return NotFound();
        await Lookups(e);
        return View("Form", e);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, Floor m)
    {
        if (id != m.FloorId) return BadRequest();
        var e = await _db.Floors.FindAsync(id);
        if (e == null) return NotFound();

        if (ModelState.IsValid)
        {
            e.FloorName = m.FloorName;
            e.BranchId = m.BranchId;
            e.Description = m.Description;
            e.IsActive = m.IsActive;

            try
            {
                await _db.SaveChangesAsync();
                TempData["Success"] = "Floor / Area updated successfully.";
                return RedirectToAction(nameof(Index));
            }
            catch (DbUpdateException)
            {
                ModelState.AddModelError("", "Could not save. A record with the same name / code may already exist.");
            }
        }
        await Lookups(m);
        return View("Form", m);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        var e = await _db.Floors.FindAsync(id);
        if (e == null) return NotFound();
        try
        {
            _db.Floors.Remove(e);
            await _db.SaveChangesAsync();
            TempData["Success"] = "Floor / Area deleted.";
        }
        catch (DbUpdateException)
        {
            TempData["Error"] = "This record is already used elsewhere and cannot be deleted. Mark it inactive instead.";
        }
        return RedirectToAction(nameof(Index));
    }

    private async Task Lookups(Floor m)
    {
        ViewBag.BranchIdList = new SelectList(
            await _db.Branches.Where(x => x.IsActive || x.BranchId == m.BranchId).OrderBy(x => x.BranchName).ToListAsync(),
            "BranchId", "BranchName", m.BranchId);
    }

}
