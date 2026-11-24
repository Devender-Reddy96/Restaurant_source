using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Controllers;

[Authorize]
public class BranchesController : Controller
{
    private readonly AppDbContext _db;

    public BranchesController(AppDbContext db)
    {
        _db = db;

    }

    public async Task<IActionResult> Index()
    {
        var list = await _db.Branches
            .OrderBy(x => x.BranchName)
            .ToListAsync();
        return View(list);
    }

    public async Task<IActionResult> Create()
    {
        var m = new Branch();
        await Lookups(m);
        return View("Form", m);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Branch m)
    {

        if (ModelState.IsValid)
        {

            try
            {
                _db.Branches.Add(m);
                await _db.SaveChangesAsync();
                TempData["Success"] = "Branch added successfully.";
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
        var e = await _db.Branches.FindAsync(id);
        if (e == null) return NotFound();
        await Lookups(e);
        return View("Form", e);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, Branch m)
    {
        if (id != m.BranchId) return BadRequest();
        var e = await _db.Branches.FindAsync(id);
        if (e == null) return NotFound();

        if (ModelState.IsValid)
        {
            e.BranchName = m.BranchName;
            e.BranchCode = m.BranchCode;
            e.Phone = m.Phone;
            e.Email = m.Email;
            e.City = m.City;
            e.State = m.State;
            e.Pincode = m.Pincode;
            e.GstNumber = m.GstNumber;
            e.FssaiNumber = m.FssaiNumber;
            e.Address = m.Address;
            e.IsActive = m.IsActive;

            try
            {
                await _db.SaveChangesAsync();
                TempData["Success"] = "Branch updated successfully.";
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
        var e = await _db.Branches.FindAsync(id);
        if (e == null) return NotFound();
        try
        {
            _db.Branches.Remove(e);
            await _db.SaveChangesAsync();
            TempData["Success"] = "Branch deleted.";
        }
        catch (DbUpdateException)
        {
            TempData["Error"] = "This record is already used elsewhere and cannot be deleted. Mark it inactive instead.";
        }
        return RedirectToAction(nameof(Index));
    }

    private Task Lookups(Branch m) => Task.CompletedTask;

}
