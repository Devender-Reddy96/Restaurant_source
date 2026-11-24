using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Controllers;

[Authorize]
public class DiscountsController : Controller
{
    private readonly AppDbContext _db;

    public DiscountsController(AppDbContext db)
    {
        _db = db;

    }

    public async Task<IActionResult> Index()
    {
        var list = await _db.Discounts
            .OrderBy(x => x.DiscountName)
            .ToListAsync();
        return View(list);
    }

    public async Task<IActionResult> Create()
    {
        var m = new Discount();
        await Lookups(m);
        return View("Form", m);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Discount m)
    {

        if (ModelState.IsValid)
        {

            try
            {
                _db.Discounts.Add(m);
                await _db.SaveChangesAsync();
                TempData["Success"] = "Discount added successfully.";
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
        var e = await _db.Discounts.FindAsync(id);
        if (e == null) return NotFound();
        await Lookups(e);
        return View("Form", e);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, Discount m)
    {
        if (id != m.DiscountId) return BadRequest();
        var e = await _db.Discounts.FindAsync(id);
        if (e == null) return NotFound();

        if (ModelState.IsValid)
        {
            e.DiscountName = m.DiscountName;
            e.DiscountCode = m.DiscountCode;
            e.DiscountType = m.DiscountType;
            e.DiscountValue = m.DiscountValue;
            e.MinOrderAmount = m.MinOrderAmount;
            e.ValidFrom = m.ValidFrom;
            e.ValidTo = m.ValidTo;
            e.IsActive = m.IsActive;

            try
            {
                await _db.SaveChangesAsync();
                TempData["Success"] = "Discount updated successfully.";
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
        var e = await _db.Discounts.FindAsync(id);
        if (e == null) return NotFound();
        try
        {
            _db.Discounts.Remove(e);
            await _db.SaveChangesAsync();
            TempData["Success"] = "Discount deleted.";
        }
        catch (DbUpdateException)
        {
            TempData["Error"] = "This record is already used elsewhere and cannot be deleted. Mark it inactive instead.";
        }
        return RedirectToAction(nameof(Index));
    }

    private Task Lookups(Discount m) => Task.CompletedTask;

}
