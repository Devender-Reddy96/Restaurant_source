using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Controllers;

[Authorize]
public class IngredientsController : Controller
{
    private readonly AppDbContext _db;

    public IngredientsController(AppDbContext db)
    {
        _db = db;

    }

    public async Task<IActionResult> Index()
    {
        var list = await _db.Ingredients
            .Include(x => x.Unit)
            .OrderBy(x => x.IngredientName)
            .ToListAsync();
        return View(list);
    }

    public async Task<IActionResult> Create()
    {
        var m = new Ingredient();
        await Lookups(m);
        return View("Form", m);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Ingredient m)
    {

        if (ModelState.IsValid)
        {

            try
            {
                _db.Ingredients.Add(m);
                await _db.SaveChangesAsync();
                TempData["Success"] = "Ingredient added successfully.";
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
        var e = await _db.Ingredients.FindAsync(id);
        if (e == null) return NotFound();
        await Lookups(e);
        return View("Form", e);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, Ingredient m)
    {
        if (id != m.IngredientId) return BadRequest();
        var e = await _db.Ingredients.FindAsync(id);
        if (e == null) return NotFound();

        if (ModelState.IsValid)
        {
            e.IngredientName = m.IngredientName;
            e.UnitId = m.UnitId;
            e.ReorderLevel = m.ReorderLevel;
            e.CostPerUnit = m.CostPerUnit;
            e.IsActive = m.IsActive;

            try
            {
                await _db.SaveChangesAsync();
                TempData["Success"] = "Ingredient updated successfully.";
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
        var e = await _db.Ingredients.FindAsync(id);
        if (e == null) return NotFound();
        try
        {
            _db.Ingredients.Remove(e);
            await _db.SaveChangesAsync();
            TempData["Success"] = "Ingredient deleted.";
        }
        catch (DbUpdateException)
        {
            TempData["Error"] = "This record is already used elsewhere and cannot be deleted. Mark it inactive instead.";
        }
        return RedirectToAction(nameof(Index));
    }

    private async Task Lookups(Ingredient m)
    {
        ViewBag.UnitIdList = new SelectList(
            await _db.Units.Where(x => x.IsActive || x.UnitId == m.UnitId).OrderBy(x => x.UnitName).ToListAsync(),
            "UnitId", "UnitName", m.UnitId);
    }

}
