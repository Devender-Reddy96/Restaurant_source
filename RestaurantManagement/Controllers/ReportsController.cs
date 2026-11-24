using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;
using RestaurantManagement.Services;

namespace RestaurantManagement.Controllers;

/// <summary>Profit &amp; loss dashboard. Income = net sales (bill total without GST) + tips received from customers.
/// Expenses = ingredient bills + other expenses + tips paid to waiters. Profit = Income - Expenses.</summary>
[Authorize]
public class ReportsController : Controller
{
    private readonly AppDbContext _db;
    public ReportsController(AppDbContext db) => _db = db;

    public IActionResult Index() => RedirectToAction(nameof(ProfitLoss));

    public IActionResult ProfitLoss() => View();

    private static DateOnly Day(CustomerOrder o) => DateOnly.FromDateTime(OrderLogic.ToIst(o.PaidOn!.Value));

    private async Task<(List<CustomerOrder>, List<RestaurantExpense>)> Load(DateOnly a, DateOnly b)
    {
        var au = OrderLogic.IstStartUtc(a); var bu = OrderLogic.IstStartUtc(b.AddDays(1));
        var orders = await _db.CustomerOrders.AsNoTracking().AsSplitQuery()
            .Include(o => o.Items).Include(o => o.Payments).Include(o => o.WaiterEmployee)
            .Where(o => o.Status == OrderStatus.Paid && o.PaidOn >= au && o.PaidOn < bu).ToListAsync();
        var exps = await _db.RestaurantExpenses.AsNoTracking()
            .Include(x => x.Supplier).Include(x => x.ExpenseCategory).Include(x => x.Employee)
            .Where(x => x.ExpenseDate >= a && x.ExpenseDate <= b).ToListAsync();
        return (orders, exps);
    }

    public async Task<IActionResult> Data(DateOnly? from, DateOnly? to)
    {
        var today = OrderLogic.TodayIst();
        var f = from ?? today; var t = to ?? today;
        if (t < f) (f, t) = (t, f);
        if (t.DayNumber - f.DayNumber > 730) f = t.AddDays(-730);
        var len = t.DayNumber - f.DayNumber + 1;
        var pf = f.AddDays(-len); var pt = f.AddDays(-1);

        var (orders, exps) = await Load(pf, t);                         // selected + previous range
        var (tOrders, tExps) = await Load(today.AddDays(-1), today);      // today + yesterday

        object Summary(List<CustomerOrder> allO, List<RestaurantExpense> allE, DateOnly a, DateOnly b)
        {
            var os = allO.Where(o => Day(o) >= a && Day(o) <= b).ToList();
            var es = allE.Where(x => x.ExpenseDate >= a && x.ExpenseDate <= b).ToList();
            var net = os.Sum(o => o.GrandTotal - o.TaxAmount);
            var tipsIn = os.Sum(o => o.TipAmount);
            var ing = es.Where(x => x.ExpenseType == ExpenseType.Ingredient).Sum(x => x.GrandTotal);
            var oth = es.Where(x => x.ExpenseType == ExpenseType.Expense).Sum(x => x.GrandTotal);
            var tip = es.Where(x => x.ExpenseType == ExpenseType.Tip).Sum(x => x.GrandTotal);
            return new
            {
                orders = os.Count, grossSales = os.Sum(o => o.GrandTotal), netSales = net, tax = os.Sum(o => o.TaxAmount),
                discount = os.Sum(o => o.DiscountAmount), tipsIn, income = net + tipsIn,
                ingredient = ing, other = oth, tips = tip, expenses = ing + oth + tip,
                profit = net + tipsIn - ing - oth - tip,
                avgBill = os.Count == 0 ? 0 : Math.Round(os.Sum(o => o.GrandTotal) / os.Count, 2),
                unpaidBills = es.Sum(x => x.Balance)
            };
        }

        var cur = orders.Where(o => Day(o) >= f && Day(o) <= t).ToList();
        var curE = exps.Where(x => x.ExpenseDate >= f && x.ExpenseDate <= t).ToList();
        var days = Enumerable.Range(0, len).Select(i => f.AddDays(i)).Select(d =>
        {
            var os = cur.Where(o => Day(o) == d).ToList(); var es = curE.Where(x => x.ExpenseDate == d).ToList();
            var net = os.Sum(o => o.GrandTotal - o.TaxAmount); var tipsIn = os.Sum(o => o.TipAmount);
            var ing = es.Where(x => x.ExpenseType == ExpenseType.Ingredient).Sum(x => x.GrandTotal);
            var oth = es.Where(x => x.ExpenseType == ExpenseType.Expense).Sum(x => x.GrandTotal);
            var tip = es.Where(x => x.ExpenseType == ExpenseType.Tip).Sum(x => x.GrandTotal);
            return new
            {
                date = d.ToString("yyyy-MM-dd"), orders = os.Count, netSales = net, tax = os.Sum(o => o.TaxAmount),
                discount = os.Sum(o => o.DiscountAmount), tipsIn, ingredient = ing, other = oth, tips = tip,
                expenses = ing + oth + tip, profit = net + tipsIn - ing - oth - tip
            };
        }).ToList();

        var expenseBreakdown = curE.GroupBy(x => x.ExpenseType == ExpenseType.Ingredient ? "Ingredients"
                : x.ExpenseType == ExpenseType.Tip ? "Tips to waiters" : (x.ExpenseCategory?.ExpenseCategoryName ?? "Other"))
            .Select(g => new { name = g.Key, amount = g.Sum(x => x.GrandTotal) }).OrderByDescending(x => x.amount).ToList();

        var bySupplier = curE.Where(x => x.ExpenseType == ExpenseType.Ingredient)
            .GroupBy(x => x.Supplier?.SupplierName ?? "-")
            .Select(g => new { name = g.Key, bills = g.Count(), amount = g.Sum(x => x.GrandTotal), balance = g.Sum(x => x.Balance) })
            .OrderByDescending(x => x.amount).ToList();

        var tipDocs = curE.Where(x => x.ExpenseType == ExpenseType.Tip).ToList();
        var waiterTips = tipDocs.GroupBy(x => x.Employee?.FullName ?? "-")
            .Select(g => new
            {
                name = g.Key,
                fromBills = g.Where(x => x.OrderId != null).Sum(x => x.GrandTotal),
                manual = g.Where(x => x.OrderId == null).Sum(x => x.GrandTotal),
                total = g.Sum(x => x.GrandTotal),
                count = g.Count(),
                bills = cur.Count(o => o.WaiterEmployee?.FullName == g.Key)
            }).OrderByDescending(x => x.total).ToList();

        var modes = cur.SelectMany(o => o.Payments).GroupBy(p => p.ModeName)
            .Select(g => new { name = g.Key, amount = g.Sum(p => p.Amount) }).OrderByDescending(x => x.amount).ToList();

        var topItems = cur.SelectMany(o => o.Items).Where(i => i.Status != ItemStatus.Cancelled)
            .GroupBy(i => i.ItemName).Select(g => new { name = g.Key, qty = g.Sum(i => i.Quantity), amount = g.Sum(i => i.LineTotal) })
            .OrderByDescending(x => x.amount).Take(10).ToList();

        var docs = curE.OrderByDescending(x => x.ExpenseDate).ThenByDescending(x => x.RestaurantExpenseId).Select(x => new
        {
            id = x.RestaurantExpenseId, docNo = x.DocNo, date = x.ExpenseDate.ToString("yyyy-MM-dd"), type = x.ExpenseType,
            party = x.PartyName, total = x.GrandTotal, paid = x.PaidAmount, balance = x.Balance, mode = x.PaymentMode
        }).ToList();

        return Json(new
        {
            from = f.ToString("yyyy-MM-dd"), to = t.ToString("yyyy-MM-dd"),
            prevFrom = pf.ToString("yyyy-MM-dd"), prevTo = pt.ToString("yyyy-MM-dd"),
            current = Summary(orders, exps, f, t), previous = Summary(orders, exps, pf, pt),
            today = Summary(tOrders, tExps, today, today), yesterday = Summary(tOrders, tExps, today.AddDays(-1), today.AddDays(-1)),
            days, expenseBreakdown, bySupplier, waiterTips, modes, topItems, docs
        });
    }
}
