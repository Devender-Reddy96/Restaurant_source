using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models;
using RestaurantManagement.Models.Entities;
using RestaurantManagement.Services;

namespace RestaurantManagement.Controllers;

/// <summary>Restaurant expense documents: Ingredient bills (supplier + many ingredients), Expenses (category) and Tips (waiter).
/// All of these are money the restaurant spends - they reduce profit.</summary>
[Authorize]
public class ExpensesController : Controller
{
    private readonly AppDbContext _db;
    public ExpensesController(AppDbContext db) => _db = db;

    public async Task<IActionResult> Index(DateOnly? from, DateOnly? to)
    {
        var today = OrderLogic.TodayIst();
        var f = from ?? today.AddDays(-(today.Day - 1)); // first day of this month
        var t = to ?? today;
        if (t < f) (f, t) = (t, f);
        var list = await _db.RestaurantExpenses.AsNoTracking()
            .Include(x => x.Supplier).Include(x => x.ExpenseCategory).Include(x => x.Employee).Include(x => x.Items)
            .Where(x => x.ExpenseDate >= f && x.ExpenseDate <= t)
            .OrderByDescending(x => x.ExpenseDate).ThenByDescending(x => x.RestaurantExpenseId).ToListAsync();
        ViewBag.From = f; ViewBag.To = t;
        return View(list);
    }

    public async Task<IActionResult> Create(string? type)
    {
        await Lookups();
        var e = new RestaurantExpense { ExpenseType = ExpenseType.All.Contains(type) ? type! : ExpenseType.Ingredient, ExpenseDate = OrderLogic.TodayIst() };
        return View("Form", e);
    }

    public async Task<IActionResult> Edit(int id)
    {
        var e = await _db.RestaurantExpenses.Include(x => x.Items).FirstOrDefaultAsync(x => x.RestaurantExpenseId == id);
        if (e == null) return NotFound();
        await Lookups();
        return View("Form", e);
    }

    public async Task<IActionResult> Details(int id)
    {
        var e = await _db.RestaurantExpenses.AsNoTracking()
            .Include(x => x.Supplier).Include(x => x.ExpenseCategory).Include(x => x.Employee).Include(x => x.Items)
            .FirstOrDefaultAsync(x => x.RestaurantExpenseId == id);
        if (e == null) return NotFound();
        ViewBag.Setting = await _db.RestaurantSettings.FirstOrDefaultAsync() ?? new RestaurantSetting();
        return View(e);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public Task<IActionResult> Create([FromBody] ExpenseSaveRequest r) => Save(r, isNew: true);

    [HttpPost, ValidateAntiForgeryToken]
    public Task<IActionResult> Edit([FromBody] ExpenseSaveRequest r) => Save(r, isNew: false);

    private async Task<IActionResult> Save(ExpenseSaveRequest r, bool isNew)
    {
        if (r == null) return Json(new { ok = false, message = "Nothing to save." });
        if (!ExpenseType.All.Contains(r.ExpenseType)) return Json(new { ok = false, message = "Select Ingredients, Expense or Tip." });
        if (r.TaxPercent < 0 || r.TaxPercent > 100 || r.DiscountPercent < 0 || r.DiscountPercent > 100)
            return Json(new { ok = false, message = "Tax % and Discount % must be between 0 and 100." });
        if (r.PaidAmount < 0) return Json(new { ok = false, message = "Paid amount cannot be negative." });
        if (r.ExpenseDate > OrderLogic.TodayIst()) return Json(new { ok = false, message = "Date cannot be in the future." });

        RestaurantExpense e;
        if (isNew)
        {
            e = new RestaurantExpense { DocNo = await OrderLogic.NextExpenseNo(_db), CreatedBy = User.Identity?.Name };
            _db.RestaurantExpenses.Add(e);
        }
        else
        {
            var found = await _db.RestaurantExpenses.Include(x => x.Items).FirstOrDefaultAsync(x => x.RestaurantExpenseId == r.Id);
            if (found == null) return Json(new { ok = false, message = "Document not found." });
            if (found.OrderId != null) return Json(new { ok = false, message = "This tip came from a customer bill and cannot be edited. Delete it and add a new one if needed." });
            e = found;
            _db.RestaurantExpenseItems.RemoveRange(e.Items);
            e.Items.Clear();
        }

        e.ExpenseType = r.ExpenseType;
        e.ExpenseDate = r.ExpenseDate;
        e.BillNo = Clip(r.BillNo, 50);
        e.Description = Clip(r.Description, 300);
        e.PaymentMode = Clip(r.PaymentMode, 50);
        e.ReferenceNo = Clip(r.ReferenceNo, 60);
        e.SupplierId = e.ExpenseCategoryId = e.EmployeeId = null;

        decimal sub;
        switch (r.ExpenseType)
        {
            case ExpenseType.Ingredient:
                if (r.SupplierId == null || !await _db.Suppliers.AnyAsync(s => s.SupplierId == r.SupplierId))
                    return Json(new { ok = false, message = "Select the supplier." });
                var lines = (r.Items ?? new()).Where(i => i.IngredientId > 0 && i.Quantity > 0).ToList();
                if (lines.Count == 0) return Json(new { ok = false, message = "Add at least one ingredient with quantity." });
                if (lines.Any(i => i.CostPerUnit < 0 || i.ReorderLevel < 0)) return Json(new { ok = false, message = "Cost and reorder level cannot be negative." });
                var ids = lines.Select(i => i.IngredientId).Distinct().ToList();
                var ings = await _db.Ingredients.Include(i => i.Unit).Where(i => ids.Contains(i.IngredientId)).ToListAsync();
                if (ings.Count != ids.Count) return Json(new { ok = false, message = "An ingredient was not found. Refresh the page." });
                e.SupplierId = r.SupplierId;
                foreach (var l in lines)
                {
                    var g = ings.First(x => x.IngredientId == l.IngredientId);
                    e.Items.Add(new RestaurantExpenseItem
                    {
                        IngredientId = g.IngredientId, IngredientName = g.IngredientName, UnitName = g.Unit?.ShortName,
                        Quantity = Math.Round(l.Quantity, 3), CostPerUnit = Math.Round(l.CostPerUnit, 2), ReorderLevel = Math.Round(l.ReorderLevel, 2),
                        Amount = Math.Round(l.Quantity * l.CostPerUnit, 2)
                    });
                    if (r.UpdateMaster) { g.CostPerUnit = Math.Round(l.CostPerUnit, 2); g.ReorderLevel = Math.Round(l.ReorderLevel, 2); }
                }
                sub = e.Items.Sum(i => i.Amount);
                break;
            case ExpenseType.Expense:
                if (r.ExpenseCategoryId == null || !await _db.ExpenseCategories.AnyAsync(c => c.ExpenseCategoryId == r.ExpenseCategoryId))
                    return Json(new { ok = false, message = "Select the expense category." });
                if (r.Amount <= 0) return Json(new { ok = false, message = "Enter the expense amount." });
                e.ExpenseCategoryId = r.ExpenseCategoryId;
                sub = Math.Round(r.Amount, 2);
                break;
            default: // Tip
                if (r.EmployeeId == null || !await _db.Employees.AnyAsync(x => x.EmployeeId == r.EmployeeId))
                    return Json(new { ok = false, message = "Select the waiter." });
                if (r.Amount <= 0) return Json(new { ok = false, message = "Enter the tip amount." });
                e.EmployeeId = r.EmployeeId;
                sub = Math.Round(r.Amount, 2);
                break;
        }

        var taxPct = r.ExpenseType == ExpenseType.Tip ? 0 : r.TaxPercent;
        var discPct = r.ExpenseType == ExpenseType.Tip ? 0 : r.DiscountPercent;
        e.SubTotal = sub;
        e.TaxPercent = taxPct;
        e.TaxAmount = Math.Round(sub * taxPct / 100, 2);
        e.DiscountPercent = discPct;
        e.DiscountAmount = Math.Round(sub * discPct / 100, 2);
        e.GrandTotal = sub + e.TaxAmount - e.DiscountAmount;
        if (r.PaidAmount > e.GrandTotal + 0.009m)
            return Json(new { ok = false, message = $"Paid amount cannot be more than the bill total ({e.GrandTotal:N2})." });
        e.PaidAmount = Math.Round(r.PaidAmount, 2);

        await _db.SaveChangesAsync();
        return Json(new { ok = true, id = e.RestaurantExpenseId, docNo = e.DocNo });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        var e = await _db.RestaurantExpenses.FindAsync(id);
        if (e == null) return NotFound();
        if (e.OrderId != null)
        {
            // Tip that came from a customer bill - keep the bill and the tip in step.
            var o = await _db.CustomerOrders.FindAsync(e.OrderId);
            if (o != null) o.TipAmount = Math.Max(0, o.TipAmount - e.GrandTotal);
        }
        _db.RestaurantExpenses.Remove(e);
        await _db.SaveChangesAsync();
        TempData["Success"] = $"Document {e.DocNo} deleted.";
        return RedirectToAction(nameof(Index));
    }

    private static string? Clip(string? v, int max) =>
        string.IsNullOrWhiteSpace(v) ? null : (v.Trim().Length > max ? v.Trim()[..max] : v.Trim());

    private async Task Lookups()
    {
        ViewBag.Suppliers = await _db.Suppliers.Where(s => s.IsActive).OrderBy(s => s.SupplierName)
            .Select(s => new IdName { Id = s.SupplierId, Name = s.SupplierName }).ToListAsync();
        ViewBag.Categories = await _db.ExpenseCategories.Where(c => c.IsActive).OrderBy(c => c.ExpenseCategoryName)
            .Select(c => new IdName { Id = c.ExpenseCategoryId, Name = c.ExpenseCategoryName }).ToListAsync();
        ViewBag.Waiters = await PosController.LoadWaiters(_db);
        ViewBag.Ingredients = await _db.Ingredients.Include(i => i.Unit).Where(i => i.IsActive).OrderBy(i => i.IngredientName)
            .Select(i => new { id = i.IngredientId, name = i.IngredientName, unit = i.Unit!.ShortName, reorder = i.ReorderLevel, cost = i.CostPerUnit })
            .ToListAsync();
        var modes = await _db.PaymentModes.Where(p => p.IsActive).OrderBy(p => p.ModeName).Select(p => p.ModeName).ToListAsync();
        ViewBag.Modes = modes.Count > 0 ? modes : new List<string> { "Cash", "UPI", "Card" };
    }
}
