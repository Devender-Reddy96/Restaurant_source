using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Controllers;

[Authorize]
public class EmployeesController : Controller
{
    private readonly AppDbContext _db;

    public EmployeesController(AppDbContext db)
    {
        _db = db;

    }

    public async Task<IActionResult> Index()
    {
        var list = await _db.Employees
            .Include(x => x.Designation)
            .Include(x => x.Shift)
            .Include(x => x.Branch)
            .OrderBy(x => x.FullName)
            .ToListAsync();
        return View(list);
    }

    public async Task<IActionResult> Create()
    {
        var m = new Employee();
        await Lookups(m);
        return View("Form", m);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Employee m)
    {

        if (ModelState.IsValid)
        {

            try
            {
                _db.Employees.Add(m);
                await _db.SaveChangesAsync();
                TempData["Success"] = "Staff Member added successfully.";
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
        var e = await _db.Employees.FindAsync(id);
        if (e == null) return NotFound();
        await Lookups(e);
        return View("Form", e);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, Employee m)
    {
        if (id != m.EmployeeId) return BadRequest();
        var e = await _db.Employees.FindAsync(id);
        if (e == null) return NotFound();

        if (ModelState.IsValid)
        {
            e.EmployeeCode = m.EmployeeCode;
            e.FullName = m.FullName;
            e.DesignationId = m.DesignationId;
            e.ShiftId = m.ShiftId;
            e.BranchId = m.BranchId;
            e.Phone = m.Phone;
            e.Email = m.Email;
            e.Gender = m.Gender;
            e.DateOfBirth = m.DateOfBirth;
            e.JoiningDate = m.JoiningDate;
            e.Salary = m.Salary;
            e.Address = m.Address;
            e.IsActive = m.IsActive;

            try
            {
                await _db.SaveChangesAsync();
                TempData["Success"] = "Staff Member updated successfully.";
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
        var e = await _db.Employees.FindAsync(id);
        if (e == null) return NotFound();
        try
        {
            _db.Employees.Remove(e);
            await _db.SaveChangesAsync();
            TempData["Success"] = "Staff Member deleted.";
        }
        catch (DbUpdateException)
        {
            TempData["Error"] = "This record is already used elsewhere and cannot be deleted. Mark it inactive instead.";
        }
        return RedirectToAction(nameof(Index));
    }

    private async Task Lookups(Employee m)
    {
        ViewBag.DesignationIdList = new SelectList(
            await _db.Designations.Where(x => x.IsActive || x.DesignationId == m.DesignationId).OrderBy(x => x.DesignationName).ToListAsync(),
            "DesignationId", "DesignationName", m.DesignationId);
        ViewBag.ShiftIdList = new SelectList(
            await _db.Shifts.Where(x => x.IsActive || x.ShiftId == m.ShiftId).OrderBy(x => x.ShiftName).ToListAsync(),
            "ShiftId", "ShiftName", m.ShiftId);
        ViewBag.BranchIdList = new SelectList(
            await _db.Branches.Where(x => x.IsActive || x.BranchId == m.BranchId).OrderBy(x => x.BranchName).ToListAsync(),
            "BranchId", "BranchName", m.BranchId);
    }

}
