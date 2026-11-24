using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Controllers;

[Authorize]
public class SuppliersController : Controller
{
    private readonly AppDbContext _db;

    public SuppliersController(AppDbContext db)
    {
        _db = db;

    }

    public async Task<IActionResult> Index()
    {
        var list = await _db.Suppliers
            .OrderBy(x => x.SupplierName)
            .ToListAsync();
        return View(list);
    }

    public async Task<IActionResult> Create()
    {
        var m = new Supplier();
        await Lookups(m);
        return View("Form", m);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Supplier m)
    {

        if (ModelState.IsValid)
        {

            try
            {
                _db.Suppliers.Add(m);
                await _db.SaveChangesAsync();
                TempData["Success"] = "Supplier added successfully.";
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
        var e = await _db.Suppliers.FindAsync(id);
        if (e == null) return NotFound();
        await Lookups(e);
        return View("Form", e);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, Supplier m)
    {
        if (id != m.SupplierId) return BadRequest();
        var e = await _db.Suppliers.FindAsync(id);
        if (e == null) return NotFound();

        if (ModelState.IsValid)
        {
            e.SupplierName = m.SupplierName;
            e.ContactPerson = m.ContactPerson;
            e.Phone = m.Phone;
            e.Email = m.Email;
            e.GstNumber = m.GstNumber;
            e.Address = m.Address;
            e.IsActive = m.IsActive;

            try
            {
                await _db.SaveChangesAsync();
                TempData["Success"] = "Supplier updated successfully.";
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
        var e = await _db.Suppliers.FindAsync(id);
        if (e == null) return NotFound();
        try
        {
            _db.Suppliers.Remove(e);
            await _db.SaveChangesAsync();
            TempData["Success"] = "Supplier deleted.";
        }
        catch (DbUpdateException)
        {
            TempData["Error"] = "This record is already used elsewhere and cannot be deleted. Mark it inactive instead.";
        }
        return RedirectToAction(nameof(Index));
    }

    private Task Lookups(Supplier m) => Task.CompletedTask;

}
