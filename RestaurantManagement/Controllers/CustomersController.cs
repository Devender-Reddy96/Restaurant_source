using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Controllers;

[Authorize]
public class CustomersController : Controller
{
    private readonly AppDbContext _db;

    public CustomersController(AppDbContext db)
    {
        _db = db;

    }

    public async Task<IActionResult> Index()
    {
        var list = await _db.Customers
            .OrderBy(x => x.CustomerName)
            .ToListAsync();
        return View(list);
    }

    public async Task<IActionResult> Create()
    {
        var m = new Customer();
        await Lookups(m);
        return View("Form", m);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Customer m)
    {

        if (ModelState.IsValid)
        {

            try
            {
                _db.Customers.Add(m);
                await _db.SaveChangesAsync();
                TempData["Success"] = "Customer added successfully.";
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
        var e = await _db.Customers.FindAsync(id);
        if (e == null) return NotFound();
        await Lookups(e);
        return View("Form", e);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, Customer m)
    {
        if (id != m.CustomerId) return BadRequest();
        var e = await _db.Customers.FindAsync(id);
        if (e == null) return NotFound();

        if (ModelState.IsValid)
        {
            e.CustomerName = m.CustomerName;
            e.Phone = m.Phone;
            e.Email = m.Email;
            e.BirthDate = m.BirthDate;
            e.LoyaltyPoints = m.LoyaltyPoints;
            e.Address = m.Address;
            e.IsActive = m.IsActive;

            try
            {
                await _db.SaveChangesAsync();
                TempData["Success"] = "Customer updated successfully.";
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
        var e = await _db.Customers.FindAsync(id);
        if (e == null) return NotFound();
        try
        {
            _db.Customers.Remove(e);
            await _db.SaveChangesAsync();
            TempData["Success"] = "Customer deleted.";
        }
        catch (DbUpdateException)
        {
            TempData["Error"] = "This record is already used elsewhere and cannot be deleted. Mark it inactive instead.";
        }
        return RedirectToAction(nameof(Index));
    }

    private Task Lookups(Customer m) => Task.CompletedTask;

}
