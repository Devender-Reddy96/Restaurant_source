using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Controllers;

[Authorize]
public class FoodItemsController : Controller
{
    private readonly AppDbContext _db;
    private readonly IWebHostEnvironment _env;

    public FoodItemsController(AppDbContext db, IWebHostEnvironment env)
    {
        _db = db;
        _env = env;
    }

    public async Task<IActionResult> Index()
    {
        var list = await _db.FoodItems
            .Include(x => x.Category)
            .Include(x => x.Tax)
            .Include(x => x.KitchenStation)
            .OrderBy(x => x.FoodName)
            .ToListAsync();
        return View(list);
    }

    public async Task<IActionResult> Create()
    {
        var m = new FoodItem();
        await Lookups(m);
        return View("Form", m);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(FoodItem m, IFormFile? imageFile)
    {
        if (imageFile != null && imageFile.Length > 2 * 1024 * 1024)
            ModelState.AddModelError("", "Photo must be 2 MB or smaller.");
        if (ModelState.IsValid)
        {
            m.ImagePath = await SaveImage(imageFile);
            try
            {
                _db.FoodItems.Add(m);
                await _db.SaveChangesAsync();
                TempData["Success"] = "Food Item added successfully.";
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
        var e = await _db.FoodItems.FindAsync(id);
        if (e == null) return NotFound();
        await Lookups(e);
        return View("Form", e);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, FoodItem m, IFormFile? imageFile)
    {
        if (id != m.FoodItemId) return BadRequest();
        var e = await _db.FoodItems.FindAsync(id);
        if (e == null) return NotFound();
        if (imageFile != null && imageFile.Length > 2 * 1024 * 1024)
            ModelState.AddModelError("", "Photo must be 2 MB or smaller.");
        if (ModelState.IsValid)
        {
            e.ItemCode = m.ItemCode;
            e.FoodName = m.FoodName;
            e.CategoryId = m.CategoryId;
            e.FoodType = m.FoodType;
            e.Price = m.Price;
            e.TaxId = m.TaxId;
            e.KitchenStationId = m.KitchenStationId;
            e.PreparationTime = m.PreparationTime;
            e.Description = m.Description;
            e.IsAvailable = m.IsAvailable;
            e.IsActive = m.IsActive;
            var newImage = await SaveImage(imageFile);
            if (newImage != null) e.ImagePath = newImage;
            try
            {
                await _db.SaveChangesAsync();
                TempData["Success"] = "Food Item updated successfully.";
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
        var e = await _db.FoodItems.FindAsync(id);
        if (e == null) return NotFound();
        try
        {
            _db.FoodItems.Remove(e);
            await _db.SaveChangesAsync();
            TempData["Success"] = "Food Item deleted.";
        }
        catch (DbUpdateException)
        {
            TempData["Error"] = "This record is already used elsewhere and cannot be deleted. Mark it inactive instead.";
        }
        return RedirectToAction(nameof(Index));
    }

    private async Task Lookups(FoodItem m)
    {
        ViewBag.CategoryIdList = new SelectList(
            await _db.Categories.Where(x => x.IsActive || x.CategoryId == m.CategoryId).OrderBy(x => x.CategoryName).ToListAsync(),
            "CategoryId", "CategoryName", m.CategoryId);
        ViewBag.TaxIdList = new SelectList(
            await _db.Taxes.Where(x => x.IsActive || x.TaxId == m.TaxId).OrderBy(x => x.TaxName).ToListAsync(),
            "TaxId", "TaxName", m.TaxId);
        ViewBag.KitchenStationIdList = new SelectList(
            await _db.KitchenStations.Where(x => x.IsActive || x.KitchenStationId == m.KitchenStationId).OrderBy(x => x.StationName).ToListAsync(),
            "KitchenStationId", "StationName", m.KitchenStationId);
    }


    private async Task<string?> SaveImage(IFormFile? file)
    {
        if (file == null || file.Length == 0) return null;
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (ext is not (".jpg" or ".jpeg" or ".png" or ".webp" or ".gif")) return null;
        var dir = Path.Combine(_env.WebRootPath, "uploads");
        Directory.CreateDirectory(dir);
        var name = Guid.NewGuid().ToString("N") + ext;
        await using var fs = new FileStream(Path.Combine(dir, name), FileMode.Create);
        await file.CopyToAsync(fs);
        return "/uploads/" + name;
    }
}
