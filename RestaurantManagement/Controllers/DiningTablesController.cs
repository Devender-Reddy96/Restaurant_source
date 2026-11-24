using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Controllers;

[Authorize]
public class DiningTablesController : Controller
{
    private readonly AppDbContext _db;

    public DiningTablesController(AppDbContext db)
    {
        _db = db;

    }

    public async Task<IActionResult> Index()
    {
        var list = await _db.DiningTables
            .Include(x => x.Floor)
            .OrderBy(x => x.TableNumber)
            .ToListAsync();
        return View(list);
    }

    public async Task<IActionResult> Create()
    {
        var m = new DiningTable();
        await Lookups(m);
        return View("Form", m);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(DiningTable m)
    {

        if (ModelState.IsValid)
        {

            try
            {
                _db.DiningTables.Add(m);
                await _db.SaveChangesAsync();
                TempData["Success"] = "Table added successfully.";
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
        var e = await _db.DiningTables.FindAsync(id);
        if (e == null) return NotFound();
        await Lookups(e);
        return View("Form", e);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, DiningTable m)
    {
        if (id != m.DiningTableId) return BadRequest();
        var e = await _db.DiningTables.FindAsync(id);
        if (e == null) return NotFound();

        if (ModelState.IsValid)
        {
            e.FloorId = m.FloorId;
            e.TableNumber = m.TableNumber;
            e.Capacity = m.Capacity;
            e.Status = m.Status;
            e.IsActive = m.IsActive;

            try
            {
                await _db.SaveChangesAsync();
                TempData["Success"] = "Table updated successfully.";
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
        var e = await _db.DiningTables.FindAsync(id);
        if (e == null) return NotFound();
        try
        {
            _db.DiningTables.Remove(e);
            await _db.SaveChangesAsync();
            TempData["Success"] = "Table deleted.";
        }
        catch (DbUpdateException)
        {
            TempData["Error"] = "This record is already used elsewhere and cannot be deleted. Mark it inactive instead.";
        }
        return RedirectToAction(nameof(Index));
    }

    private async Task Lookups(DiningTable m)
    {
        ViewBag.FloorIdList = new SelectList(
            await _db.Floors.Where(x => x.IsActive || x.FloorId == m.FloorId).OrderBy(x => x.FloorName).ToListAsync(),
            "FloorId", "FloorName", m.FloorId);
    }

}
