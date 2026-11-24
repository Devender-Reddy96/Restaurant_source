using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models;
using RestaurantManagement.Models.Entities;
using RestaurantManagement.Services;

namespace RestaurantManagement.Controllers;

[Authorize]
public class PosController : Controller
{
    private readonly AppDbContext _db;
    public PosController(AppDbContext db) => _db = db;

    // ---------- tables board + waiting queue ----------
    public async Task<IActionResult> Index()
    {
        var tables = await _db.DiningTables.Include(t => t.Floor)
            .Where(t => t.IsActive).OrderBy(t => t.Floor!.FloorName).ThenBy(t => t.TableNumber).ToListAsync();

        var openDine = await _db.CustomerOrders.Include(o => o.Items)
            .Where(o => o.Status == OrderStatus.Open && o.DiningTableId != null).ToListAsync();

        var vm = new PosHomeViewModel();
        foreach (var g in tables.GroupBy(t => t.Floor?.FloorName ?? "Tables"))
        {
            vm.Floors.Add(new FloorGroup
            {
                FloorName = g.Key,
                Tables = g.Select(t => new TableCard
                {
                    Table = t,
                    Order = openDine.FirstOrDefault(o => o.DiningTableId == t.DiningTableId)
                }).ToList()
            });
        }
        vm.FreeTables = tables.Where(t => t.Status == "Available").ToList();
        vm.Waiting = await _db.TableWaitings.Where(w => w.Status == "Waiting").OrderBy(w => w.CreatedOn).ToListAsync();
        vm.Parcels = await _db.CustomerOrders.Include(o => o.Items)
            .Where(o => o.Status == OrderStatus.Open && o.OrderType == "Parcel").OrderBy(o => o.CreatedOn).ToListAsync();
        return View(vm);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> AddWaiting(string customerName, string? mobile, int partySize)
    {
        if (string.IsNullOrWhiteSpace(customerName)) { TempData["Error"] = "Enter the customer name."; return RedirectToAction(nameof(Index)); }
        var m = OrderLogic.CleanMobile(mobile);
        if (!string.IsNullOrWhiteSpace(mobile) && m == null) { TempData["Error"] = "Enter a valid 10-digit mobile number."; return RedirectToAction(nameof(Index)); }
        _db.TableWaitings.Add(new TableWaiting { CustomerName = customerName.Trim(), Mobile = m, PartySize = Math.Max(1, partySize) });
        await _db.SaveChangesAsync();
        TempData["Success"] = "Added to the table queue.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> CancelWaiting(int id)
    {
        var w = await _db.TableWaitings.FindAsync(id);
        if (w != null) { w.Status = "Cancelled"; await _db.SaveChangesAsync(); }
        return RedirectToAction(nameof(Index));
    }

    /// <summary>Assign a free table to a waiting customer and open the order screen.</summary>
    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> SeatWaiting(int id, int tableId)
    {
        var w = await _db.TableWaitings.FindAsync(id);
        var t = await _db.DiningTables.FindAsync(tableId);
        if (w == null || t == null || t.Status != "Available")
        {
            TempData["Error"] = "That table is not available.";
            return RedirectToAction(nameof(Index));
        }
        t.Status = "Occupied";
        w.Status = "Seated"; w.AssignedTableId = t.DiningTableId; w.SeatedOn = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return RedirectToAction(nameof(Order), new { tableId, name = w.CustomerName, mobile = w.Mobile, guests = w.PartySize, waitingId = w.TableWaitingId });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> ReleaseTable(int id)
    {
        var hasOpen = await _db.CustomerOrders.AnyAsync(o => o.DiningTableId == id && o.Status == OrderStatus.Open);
        if (hasOpen) { TempData["Error"] = "This table still has an open order."; return RedirectToAction(nameof(Index)); }
        var t = await _db.DiningTables.FindAsync(id);
        if (t != null) { t.Status = "Available"; await _db.SaveChangesAsync(); }
        return RedirectToAction(nameof(Index));
    }

    // ---------- order taking ----------
    public async Task<IActionResult> Order(int? tableId, int? orderId, string? type, string? name, string? mobile, int? guests, int? waitingId)
    {
        CustomerOrder? order = null;
        if (orderId != null)
            order = await _db.CustomerOrders.Include(o => o.Items).Include(o => o.DiningTable)
                .FirstOrDefaultAsync(o => o.OrderId == orderId && o.Status == OrderStatus.Open);
        else if (tableId != null)
            order = await _db.CustomerOrders.Include(o => o.Items).Include(o => o.DiningTable)
                .FirstOrDefaultAsync(o => o.DiningTableId == tableId && o.Status == OrderStatus.Open);

        var vm = new OrderScreenViewModel
        {
            Order = order,
            OrderType = order?.OrderType ?? (string.Equals(type, "Parcel", StringComparison.OrdinalIgnoreCase) ? "Parcel" : "DineIn"),
            CustomerName = order?.CustomerName ?? name,
            CustomerMobile = order?.CustomerMobile ?? mobile,
            Guests = order?.Guests ?? guests ?? 2,
            WaitingId = waitingId,
            WaiterEmployeeId = order?.WaiterEmployeeId
        };

        if (vm.OrderType == "DineIn")
        {
            var tid = order?.DiningTableId ?? tableId;
            if (tid == null) { TempData["Error"] = "Pick a table first."; return RedirectToAction(nameof(Index)); }
            vm.Table = order?.DiningTable ?? await _db.DiningTables.FindAsync(tid);
            if (vm.Table == null) return NotFound();
        }

        var foods = await _db.FoodItems.Include(f => f.Category).Include(f => f.Tax)
            .Where(f => f.IsActive && f.IsAvailable)
            .OrderBy(f => f.Category!.DisplayOrder).ThenBy(f => f.FoodName).ToListAsync();
        vm.Menu = foods.Select(f => new MenuItemDto
        {
            Id = f.FoodItemId, Name = f.FoodName, Category = f.Category?.CategoryName ?? "Others",
            FoodType = f.FoodType, Price = f.Price, TaxPercent = f.Tax?.TaxPercentage ?? 0,
            TaxInclusive = f.Tax?.IsInclusive ?? false, Image = f.ImagePath, PrepMinutes = f.PreparationTime
        }).ToList();
        vm.Categories = vm.Menu.Select(m => m.Category).Distinct().ToList();

        vm.Addons = await _db.Addons.Where(a => a.IsActive).OrderBy(a => a.AddonName)
            .Select(a => new AddonDto { Id = a.AddonId, Name = a.AddonName, Price = a.Price }).ToListAsync();
        var map = await _db.Database.SqlQuery<FoodAddonRow>(
            $"SELECT food_item_id AS \"FoodItemId\", addon_id AS \"AddonId\" FROM menu.food_addon_mapping").ToListAsync();
        foreach (var m in vm.Menu) m.AddonIds = map.Where(x => x.FoodItemId == m.Id).Select(x => x.AddonId).ToList();
        vm.Waiters = await LoadWaiters(_db);
        return View(vm);
    }

    public class FoodAddonRow { public int FoodItemId { get; set; } public int AddonId { get; set; } }

    /// <summary>Waiters / captains for the "table bearer" drop-down (all active staff if none are tagged).</summary>
    public static async Task<List<IdName>> LoadWaiters(AppDbContext db)
    {
        var q = db.Employees.Include(e => e.Designation).Where(e => e.IsActive);
        var list = await q.Where(e => e.Designation!.DesignationName == "Waiter" || e.Designation!.DesignationName == "Captain")
            .OrderBy(e => e.FullName).Select(e => new IdName { Id = e.EmployeeId, Name = e.FullName }).ToListAsync();
        if (list.Count == 0)
            list = await q.OrderBy(e => e.FullName).Select(e => new IdName { Id = e.EmployeeId, Name = e.FullName }).ToListAsync();
        return list;
    }

    /// <summary>Change the table bearer (waiter) of an open order.</summary>
    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> SetWaiter(int id, int? waiterEmployeeId)
    {
        var o = await _db.CustomerOrders.FindAsync(id);
        if (o == null) return NotFound();
        o.WaiterEmployeeId = waiterEmployeeId;
        await _db.SaveChangesAsync();
        return Json(new { ok = true });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> PlaceOrder([FromBody] PlaceOrderRequest r)
    {
        if (r?.Lines == null || r.Lines.Count == 0) return Json(new { ok = false, message = "Add at least one item." });

        var mobile = OrderLogic.CleanMobile(r.CustomerMobile);
        if (!string.IsNullOrWhiteSpace(r.CustomerMobile) && mobile == null)
            return Json(new { ok = false, message = "Enter a valid 10-digit mobile number." });

        var ids = r.Lines.Select(l => l.FoodItemId).Distinct().ToList();
        var foods = await _db.FoodItems.Include(f => f.Tax)
            .Where(f => ids.Contains(f.FoodItemId) && f.IsActive && f.IsAvailable).ToListAsync();
        if (foods.Count != ids.Count) return Json(new { ok = false, message = "An item is no longer available. Refresh the menu." });

        CustomerOrder? order = null;
        if (r.OrderId != null)
            order = await _db.CustomerOrders.Include(o => o.Items).FirstOrDefaultAsync(o => o.OrderId == r.OrderId && o.Status == OrderStatus.Open);
        else if (r.OrderType == "DineIn" && r.DiningTableId != null)
            order = await _db.CustomerOrders.Include(o => o.Items)
                .FirstOrDefaultAsync(o => o.DiningTableId == r.DiningTableId && o.Status == OrderStatus.Open);

        if (order == null)
        {
            var parcel = r.OrderType == "Parcel";
            if (!parcel)
            {
                if (r.DiningTableId == null) return Json(new { ok = false, message = "Select a table." });
                var table = await _db.DiningTables.FindAsync(r.DiningTableId);
                if (table == null) return Json(new { ok = false, message = "Table not found." });
                table.Status = "Occupied";
            }
            var seq = await _db.Database.SqlQuery<long>($"SELECT nextval('pos.order_no_seq') AS \"Value\"").SingleAsync();
            order = new CustomerOrder
            {
                OrderNo = (parcel ? "P-" : "D-") + seq,
                OrderType = parcel ? "Parcel" : "DineIn",
                DiningTableId = parcel ? null : r.DiningTableId,
                Guests = Math.Max(1, r.Guests),
                CustomerName = string.IsNullOrWhiteSpace(r.CustomerName) ? null : r.CustomerName.Trim(),
                CustomerMobile = mobile,
                Notes = r.Notes,
                WaiterEmployeeId = r.WaiterEmployeeId,
                CreatedBy = User.Identity?.Name
            };
            if (mobile != null) order.CustomerId = await UpsertCustomer(order.CustomerName, mobile);
            _db.CustomerOrders.Add(order);
        }
        else if (order.CustomerMobile == null && mobile != null)
        {
            order.CustomerMobile = mobile;
            order.CustomerName ??= string.IsNullOrWhiteSpace(r.CustomerName) ? null : r.CustomerName.Trim();
            order.CustomerId = await UpsertCustomer(order.CustomerName, mobile);
        }

        if (r.WaiterEmployeeId != null) order.WaiterEmployeeId = r.WaiterEmployeeId;

        var addonIds = r.Lines.SelectMany(l => l.AddonIds ?? new()).Distinct().ToList();
        var addons = addonIds.Count == 0 ? new List<Addon>()
            : await _db.Addons.Where(a => addonIds.Contains(a.AddonId) && a.IsActive).ToListAsync();

        var round = order.Items.Count == 0 ? 1 : order.Items.Max(i => i.RoundNo) + 1;
        foreach (var l in r.Lines.Where(l => l.Quantity > 0))
        {
            var f = foods.First(x => x.FoodItemId == l.FoodItemId);
            var it = new OrderItem
            {
                FoodItemId = f.FoodItemId, ItemName = f.FoodName, FoodType = f.FoodType,
                Quantity = Math.Min(l.Quantity, 99), UnitPrice = f.Price,
                TaxPercent = f.Tax?.TaxPercentage ?? 0, TaxInclusive = f.Tax?.IsInclusive ?? false,
                Note = string.IsNullOrWhiteSpace(l.Note) ? null : l.Note.Trim(),
                KitchenStationId = f.KitchenStationId, RoundNo = round
            };
            foreach (var a in addons.Where(a => (l.AddonIds ?? new()).Contains(a.AddonId)))
                it.Addons.Add(new OrderItemAddon { AddonId = a.AddonId, AddonName = a.AddonName, Price = a.Price });
            if (it.Addons.Count > 0)
            {
                it.AddonUnitPrice = it.Addons.Sum(a => a.Price);
                it.AddonNames = string.Join(", ", it.Addons.Select(a => a.AddonName));
                if (it.AddonNames.Length > 300) it.AddonNames = it.AddonNames[..300];
            }
            OrderLogic.PriceLine(it);
            order.Items.Add(it);
        }
        OrderLogic.Recalculate(order);

        if (r.WaitingId != null)
        {
            var w = await _db.TableWaitings.FindAsync(r.WaitingId);
            if (w != null && w.Status != "Seated") { w.Status = "Seated"; w.SeatedOn = DateTime.UtcNow; }
        }

        await _db.SaveChangesAsync();
        return Json(new { ok = true, orderId = order.OrderId, orderNo = order.OrderNo });
    }

    private async Task<int?> UpsertCustomer(string? name, string mobile)
    {
        try
        {
            var c = await _db.Customers.FirstOrDefaultAsync(x => x.Phone == mobile);
            if (c == null)
            {
                c = new Customer { CustomerName = string.IsNullOrWhiteSpace(name) ? "Guest " + mobile[^4..] : name!, Phone = mobile };
                _db.Customers.Add(c);
                await _db.SaveChangesAsync();
            }
            return c.CustomerId;
        }
        catch (DbUpdateException) { return null; }
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> CancelItem(int id)
    {
        var it = await _db.OrderItems.Include(i => i.Order!).ThenInclude(o => o.Items).FirstOrDefaultAsync(i => i.OrderItemId == id);
        if (it == null || it.Order == null) return NotFound();
        if (it.Status != ItemStatus.New || it.Order.Status != OrderStatus.Open)
        { TempData["Error"] = "Only items not yet started by the kitchen can be cancelled."; }
        else
        {
            it.Status = ItemStatus.Cancelled;
            OrderLogic.Recalculate(it.Order);
            await _db.SaveChangesAsync();
            TempData["Success"] = "Item cancelled.";
        }
        return RedirectToAction(nameof(Order), new { orderId = it.OrderId });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> CancelOrder(int id)
    {
        var o = await _db.CustomerOrders.Include(x => x.Items).FirstOrDefaultAsync(x => x.OrderId == id);
        if (o == null) return NotFound();
        if (o.Status != OrderStatus.Open || o.PaidAmount > 0 || o.Items.Any(i => i.Status is ItemStatus.Ready or ItemStatus.Served))
        { TempData["Error"] = "This order has food ready/served or payments, so it cannot be cancelled."; return RedirectToAction(nameof(Orders)); }
        o.Status = OrderStatus.Cancelled;
        foreach (var i in o.Items) i.Status = ItemStatus.Cancelled;
        OrderLogic.Recalculate(o);
        if (o.DiningTableId != null)
        {
            var t = await _db.DiningTables.FindAsync(o.DiningTableId);
            if (t != null) t.Status = "Available";
        }
        await _db.SaveChangesAsync();
        TempData["Success"] = "Order cancelled.";
        return RedirectToAction(nameof(Orders));
    }

    // ---------- order queue ----------
    public async Task<IActionResult> Orders()
    {
        var list = await _db.CustomerOrders.Include(o => o.Items).Include(o => o.DiningTable)
            .Where(o => o.Status == OrderStatus.Open).OrderBy(o => o.CreatedOn).ToListAsync();
        return View(list);
    }
}
