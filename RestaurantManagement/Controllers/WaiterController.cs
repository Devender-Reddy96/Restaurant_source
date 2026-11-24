using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models;
using RestaurantManagement.Models.Entities;
using RestaurantManagement.Services;

namespace RestaurantManagement.Controllers;

/// <summary>"Bearer" / waiter screen: shows food that the kitchen marked Ready and beeps on new arrivals.</summary>
[Authorize]
public class WaiterController : Controller
{
    private readonly AppDbContext _db;
    public WaiterController(AppDbContext db) => _db = db;

    public IActionResult Index() => View();

    public async Task<IActionResult> Ready()
    {
        var orders = await _db.CustomerOrders.AsNoTracking().Include(o => o.Items).Include(o => o.DiningTable)
            .Where(o => o.Status != OrderStatus.Cancelled && o.Items.Any(i => i.Status == ItemStatus.Ready))
            .ToListAsync();
        foreach (var o in orders) o.Items = o.Items.Where(i => i.Status == ItemStatus.Ready).OrderBy(i => i.ReadyOn).ToList();
        orders = orders.OrderBy(o => o.Items.Min(i => i.ReadyOn)).ToList();
        return PartialView("_Ready", new ReadyBoardViewModel { Orders = orders });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Served(int id)
    {
        var it = await _db.OrderItems.FindAsync(id);
        if (it == null) return NotFound();
        if (it.Status == ItemStatus.Ready) { it.Status = ItemStatus.Served; it.ServedOn = DateTime.UtcNow; }
        await _db.SaveChangesAsync();
        await CloseIfDone(it.OrderId);
        return Json(new { ok = true });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> ServedOrder(int orderId)
    {
        var items = await _db.OrderItems.Where(i => i.OrderId == orderId && i.Status == ItemStatus.Ready).ToListAsync();
        foreach (var it in items) { it.Status = ItemStatus.Served; it.ServedOn = DateTime.UtcNow; }
        await _db.SaveChangesAsync();
        await CloseIfDone(orderId);
        return Json(new { ok = true });
    }

    private async Task CloseIfDone(int orderId)
    {
        var o = await _db.CustomerOrders.Include(x => x.Items).FirstOrDefaultAsync(x => x.OrderId == orderId);
        if (o == null) return;
        await OrderLogic.ReleaseTableIfDone(_db, o);
        await _db.SaveChangesAsync();
    }
}
