using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Controllers;

[Authorize]
public class KitchenStationsController : Controller
{
    private readonly AppDbContext _db;

    public KitchenStationsController(AppDbContext db)
    {
        _db = db;

    }

    public async Task<IActionResult> Index()
    {
        var list = await _db.KitchenStations
            .OrderBy(x => x.StationName)
            .ToListAsync();
        return View(list);
    }

    public async Task<IActionResult> Create()
    {
        var m = new KitchenStation();
        await Lookups(m);
        return View("Form", m);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(KitchenStation m)
    {

        if (ModelState.IsValid)
        {

            try
            {
                _db.KitchenStations.Add(m);
                await _db.SaveChangesAsync();
                TempData["Success"] = "Kitchen Station added successfully.";
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
        var e = await _db.KitchenStations.FindAsync(id);
        if (e == null) return NotFound();
        await Lookups(e);
        return View("Form", e);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, KitchenStation m)
    {
        if (id != m.KitchenStationId) return BadRequest();
        var e = await _db.KitchenStations.FindAsync(id);
        if (e == null) return NotFound();

        if (ModelState.IsValid)
        {
            e.StationName = m.StationName;
            e.PrinterName = m.PrinterName;
            e.Description = m.Description;
            e.IsActive = m.IsActive;

            try
            {
                await _db.SaveChangesAsync();
                TempData["Success"] = "Kitchen Station updated successfully.";
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
        var e = await _db.KitchenStations.FindAsync(id);
        if (e == null) return NotFound();
        try
        {
            _db.KitchenStations.Remove(e);
            await _db.SaveChangesAsync();
            TempData["Success"] = "Kitchen Station deleted.";
        }
        catch (DbUpdateException)
        {
            TempData["Error"] = "This record is already used elsewhere and cannot be deleted. Mark it inactive instead.";
        }
        return RedirectToAction(nameof(Index));
    }

    private Task Lookups(KitchenStation m) => Task.CompletedTask;

}
