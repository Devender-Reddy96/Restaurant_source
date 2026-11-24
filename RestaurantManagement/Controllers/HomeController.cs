using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models;

namespace RestaurantManagement.Controllers;

[Authorize]
public class HomeController : Controller
{
    private readonly AppDbContext _db;
    public HomeController(AppDbContext db) => _db = db;

    public async Task<IActionResult> Index()
    {
        var vm = new DashboardViewModel
        {
            Categories = await _db.Categories.CountAsync(x => x.IsActive),
            FoodItems = await _db.FoodItems.CountAsync(x => x.IsActive),
            Tables = await _db.DiningTables.CountAsync(x => x.IsActive),
            Staff = await _db.Employees.CountAsync(x => x.IsActive),
            Suppliers = await _db.Suppliers.CountAsync(x => x.IsActive),
            Customers = await _db.Customers.CountAsync(x => x.IsActive)
        };

        var statuses = await _db.DiningTables.Where(t => t.IsActive).Select(t => t.Status).ToListAsync();
        vm.TableStatus = statuses.GroupBy(s => s)
            .Select(g => new NameCount { Name = g.Key, Count = g.Count() }).OrderBy(x => x.Name).ToList();

        var cats = await _db.FoodItems.Where(f => f.IsActive).Select(f => f.Category!.CategoryName).ToListAsync();
        vm.ItemsByCategory = cats.GroupBy(c => c)
            .Select(g => new NameCount { Name = g.Key, Count = g.Count() }).OrderByDescending(x => x.Count).ToList();

        vm.RecentItems = await _db.FoodItems.Include(f => f.Category)
            .OrderByDescending(f => f.CreatedOn).Take(6).ToListAsync();

        return View(vm);
    }

    [AllowAnonymous]
    public IActionResult Error() => View();
}
