using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Controllers;

[Authorize]
public class CategoriesController : Controller
{
    private readonly AppDbContext _db;

    public CategoriesController(AppDbContext db)
    {
        _db = db;

    }

    public async Task<IActionResult> Index()
    {
        var list = await _db.Categories
            .OrderBy(x => x.CategoryName)
            .ToListAsync();
        return View(list);
    }

    public async Task<IActionResult> Create()
    {
        var m = new Category();
        await Lookups(m);
        return View("Form", m);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Category m)
    {

        if (ModelState.IsValid)
        {

            try
            {
                _db.Categories.Add(m);
                await _db.SaveChangesAsync();
                TempData["Success"] = "Category added successfully.";
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
        var e = await _db.Categories.FindAsync(id);
        if (e == null) return NotFound();
        await Lookups(e);
        return View("Form", e);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, Category m)
    {
        if (id != m.CategoryId) return BadRequest();
        var e = await _db.Categories.FindAsync(id);
        if (e == null) return NotFound();

        if (ModelState.IsValid)
        {
            e.CategoryName = m.CategoryName;
            e.Description = m.Description;
            e.DisplayOrder = m.DisplayOrder;
            e.IsActive = m.IsActive;

            try
            {
                await _db.SaveChangesAsync();
                TempData["Success"] = "Category updated successfully.";
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
        var e = await _db.Categories.FindAsync(id);
        if (e == null) return NotFound();
        try
        {
            _db.Categories.Remove(e);
            await _db.SaveChangesAsync();
            TempData["Success"] = "Category deleted.";
        }
        catch (DbUpdateException)
        {
            TempData["Error"] = "This record is already used elsewhere and cannot be deleted. Mark it inactive instead.";
        }
        return RedirectToAction(nameof(Index));
    }

    private Task Lookups(Category m) => Task.CompletedTask;

}
