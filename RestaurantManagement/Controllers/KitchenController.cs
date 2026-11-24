using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Controllers;

[Authorize]
public class KitchenController : Controller
{
    private readonly AppDbContext _db;
    public KitchenController(AppDbContext db) => _db = db;

    public async Task<IActionResult> Index(int? stationId)
    {
        ViewBag.Stations = new SelectList(await _db.KitchenStations.Where(s => s.IsActive).OrderBy(s => s.StationName).ToListAsync(),
            "KitchenStationId", "StationName", stationId);
        ViewBag.StationId = stationId;
        return View();
    }

    /// <summary>Polled every few seconds by the kitchen screen.</summary>
    public async Task<IActionResult> Board(int? stationId)
    {
        var orders = await _db.CustomerOrders.AsNoTracking().Include(o => o.Items).Include(o => o.DiningTable)
            .Where(o => o.Status != OrderStatus.Cancelled &&
                        o.Items.Any(i => i.Status == ItemStatus.New || i.Status == ItemStatus.Preparing))
            .OrderBy(o => o.CreatedOn).ToListAsync();

        bool Mine(OrderItem i) => stationId == null || i.KitchenStationId == null || i.KitchenStationId == stationId;

        foreach (var o in orders)
            o.Items = o.Items.Where(i => i.Status != ItemStatus.Cancelled && i.Status != ItemStatus.Served && Mine(i))
                .OrderBy(i => i.RoundNo).ThenBy(i => i.OrderItemId).ToList();
        orders = orders.Where(o => o.Items.Any(i => i.Status is ItemStatus.New or ItemStatus.Preparing)).ToList();

        var vm = new KitchenBoardViewModel
        {
            Orders = orders,
            StationId = stationId,
            Pending = orders.SelectMany(o => o.Items).Where(i => i.Status is ItemStatus.New or ItemStatus.Preparing)
                .GroupBy(i => i.ItemName).Select(g => new PendingDish { Name = g.Key, Quantity = g.Sum(x => x.Quantity) })
                .OrderByDescending(p => p.Quantity).ToList()
        };
        return PartialView("_Board", vm);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> SetStatus(int id, string status)
    {
        if (status != ItemStatus.Preparing && status != ItemStatus.Ready) return BadRequest();
        var it = await _db.OrderItems.FindAsync(id);
        if (it == null) return NotFound();
        if (it.Status is ItemStatus.Cancelled or ItemStatus.Served) return Json(new { ok = false });
        Apply(it, status);
        await _db.SaveChangesAsync();
        return Json(new { ok = true });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> SetOrderStatus(int orderId, string status, int? stationId)
    {
        if (status != ItemStatus.Preparing && status != ItemStatus.Ready) return BadRequest();
        var items = await _db.OrderItems.Where(i => i.OrderId == orderId &&
            (i.Status == ItemStatus.New || i.Status == ItemStatus.Preparing) &&
            (stationId == null || i.KitchenStationId == null || i.KitchenStationId == stationId)).ToListAsync();
        foreach (var it in items)
        {
            if (status == ItemStatus.Preparing && it.Status != ItemStatus.New) continue;
            Apply(it, status);
        }
        await _db.SaveChangesAsync();
        return Json(new { ok = true });
    }

    private static void Apply(OrderItem it, string status)
    {
        var now = DateTime.UtcNow;
        if (status == ItemStatus.Preparing) { it.Status = status; it.StartedOn ??= now; }
        else { it.Status = ItemStatus.Ready; it.StartedOn ??= now; it.ReadyOn = now; }
    }
}
