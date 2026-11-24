using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Controllers;

[Authorize]
public class PaymentModesController : Controller
{
    private readonly AppDbContext _db;

    public PaymentModesController(AppDbContext db)
    {
        _db = db;

    }

    public async Task<IActionResult> Index()
    {
        var list = await _db.PaymentModes
            .OrderBy(x => x.ModeName)
            .ToListAsync();
        return View(list);
    }

    public async Task<IActionResult> Create()
    {
        var m = new PaymentMode();
        await Lookups(m);
        return View("Form", m);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(PaymentMode m)
    {

        if (ModelState.IsValid)
        {

            try
            {
                _db.PaymentModes.Add(m);
                await _db.SaveChangesAsync();
                TempData["Success"] = "Payment Mode added successfully.";
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
        var e = await _db.PaymentModes.FindAsync(id);
        if (e == null) return NotFound();
        await Lookups(e);
        return View("Form", e);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, PaymentMode m)
    {
        if (id != m.PaymentModeId) return BadRequest();
        var e = await _db.PaymentModes.FindAsync(id);
        if (e == null) return NotFound();

        if (ModelState.IsValid)
        {
            e.ModeName = m.ModeName;
            e.ModeType = m.ModeType;
            e.RequiresReference = m.RequiresReference;
            e.IsActive = m.IsActive;

            try
            {
                await _db.SaveChangesAsync();
                TempData["Success"] = "Payment Mode updated successfully.";
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
        var e = await _db.PaymentModes.FindAsync(id);
        if (e == null) return NotFound();
        try
        {
            _db.PaymentModes.Remove(e);
            await _db.SaveChangesAsync();
            TempData["Success"] = "Payment Mode deleted.";
        }
        catch (DbUpdateException)
        {
            TempData["Error"] = "This record is already used elsewhere and cannot be deleted. Mark it inactive instead.";
        }
        return RedirectToAction(nameof(Index));
    }

    private Task Lookups(PaymentMode m) => Task.CompletedTask;

}
