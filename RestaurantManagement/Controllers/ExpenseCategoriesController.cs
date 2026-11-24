using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Controllers;

[Authorize]
public class ExpenseCategoriesController : Controller
{
    private readonly AppDbContext _db;

    public ExpenseCategoriesController(AppDbContext db)
    {
        _db = db;

    }

    public async Task<IActionResult> Index()
    {
        var list = await _db.ExpenseCategories
            .OrderBy(x => x.ExpenseCategoryName)
            .ToListAsync();
        return View(list);
    }

    public async Task<IActionResult> Create()
    {
        var m = new ExpenseCategory();
        await Lookups(m);
        return View("Form", m);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(ExpenseCategory m)
    {

        if (ModelState.IsValid)
        {

            try
            {
                _db.ExpenseCategories.Add(m);
                await _db.SaveChangesAsync();
                TempData["Success"] = "Expense Category added successfully.";
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
        var e = await _db.ExpenseCategories.FindAsync(id);
        if (e == null) return NotFound();
        await Lookups(e);
        return View("Form", e);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, ExpenseCategory m)
    {
        if (id != m.ExpenseCategoryId) return BadRequest();
        var e = await _db.ExpenseCategories.FindAsync(id);
        if (e == null) return NotFound();

        if (ModelState.IsValid)
        {
            e.ExpenseCategoryName = m.ExpenseCategoryName;
            e.Description = m.Description;
            e.IsActive = m.IsActive;

            try
            {
                await _db.SaveChangesAsync();
                TempData["Success"] = "Expense Category updated successfully.";
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
        var e = await _db.ExpenseCategories.FindAsync(id);
        if (e == null) return NotFound();
        try
        {
            _db.ExpenseCategories.Remove(e);
            await _db.SaveChangesAsync();
            TempData["Success"] = "Expense Category deleted.";
        }
        catch (DbUpdateException)
        {
            TempData["Error"] = "This record is already used elsewhere and cannot be deleted. Mark it inactive instead.";
        }
        return RedirectToAction(nameof(Index));
    }

    private Task Lookups(ExpenseCategory m) => Task.CompletedTask;

}
