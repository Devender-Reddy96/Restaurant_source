using System.Net;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models;
using RestaurantManagement.Models.Entities;
using RestaurantManagement.Services;

namespace RestaurantManagement.Controllers;

[Authorize]
public class BillingController : Controller
{
    private readonly AppDbContext _db;
    public BillingController(AppDbContext db) => _db = db;

    /// <summary>Unpaid bills + full bill grid (payment mode, tax %, discount %, tip) with filters.</summary>
    public async Task<IActionResult> Index(DateOnly? from, DateOnly? to, string? status)
    {
        var today = OrderLogic.TodayIst();
        var f = from ?? today; var t = to ?? today;
        if (t < f) (f, t) = (t, f);
        status = string.IsNullOrWhiteSpace(status) ? "Paid" : status;

        var open = await _db.CustomerOrders.Include(o => o.Items).Include(o => o.DiningTable)
            .Where(o => o.Status == OrderStatus.Open).OrderBy(o => o.CreatedOn).ToListAsync();

        var fu = OrderLogic.IstStartUtc(f); var tu = OrderLogic.IstStartUtc(t.AddDays(1));
        var q = _db.CustomerOrders.AsNoTracking().Include(o => o.DiningTable).Include(o => o.Payments).Include(o => o.WaiterEmployee)
            .Where(o => (o.PaidOn ?? o.CreatedOn) >= fu && (o.PaidOn ?? o.CreatedOn) < tu);
        if (status != "All") q = q.Where(o => o.Status == status);
        ViewBag.Grid = await q.OrderByDescending(o => o.PaidOn ?? o.CreatedOn).ToListAsync();
        ViewBag.From = f; ViewBag.To = t; ViewBag.Status = status;
        ViewBag.Modes = await _db.PaymentModes.Where(p => p.IsActive).OrderBy(p => p.ModeName).Select(p => p.ModeName).ToListAsync();
        return View(open);
    }

    public async Task<IActionResult> Bill(int id)
    {
        var o = await LoadOrder(id);
        if (o == null) return NotFound();
        return View(await BuildVm(o));
    }

    public async Task<IActionResult> Receipt(int id)
    {
        var o = await LoadOrder(id);
        if (o == null) return NotFound();
        return View(await BuildVm(o));
    }

    /// <summary>Manual discount, as a percentage or a flat amount. Value 0 removes the discount.</summary>
    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> SetDiscount(int id, string discountType, decimal value)
    {
        var o = await LoadOrder(id);
        if (o == null) return NotFound();
        if (o.Status != OrderStatus.Open) { TempData["Error"] = "Bill is already closed."; return RedirectToAction(nameof(Bill), new { id }); }
        if (value < 0) value = 0;
        o.DiscountId = null; o.DiscountCode = null;
        if (discountType == "Percent")
        {
            if (value > 100) { TempData["Error"] = "Discount % cannot be more than 100."; return RedirectToAction(nameof(Bill), new { id }); }
            o.DiscountPercent = value;
        }
        else
        {
            o.DiscountPercent = 0;
            o.DiscountAmount = Math.Min(value, o.SubTotal + o.TaxAmount);
        }
        OrderLogic.Recalculate(o);
        if (o.PaidAmount > o.GrandTotal) { TempData["Error"] = "Discount would make the bill less than what is already paid."; return RedirectToAction(nameof(Bill), new { id }); }
        await _db.SaveChangesAsync();
        TempData["Success"] = value == 0 ? "Discount removed." : "Discount applied.";
        return RedirectToAction(nameof(Bill), new { id });
    }

    /// <summary>Apply a coupon code from Discounts &amp; Coupons - only inside its validity dates and above its minimum order.</summary>
    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> ApplyCoupon(int id, string? code)
    {
        var o = await LoadOrder(id);
        if (o == null) return NotFound();
        if (o.Status != OrderStatus.Open) { TempData["Error"] = "Bill is already closed."; return RedirectToAction(nameof(Bill), new { id }); }
        code = (code ?? "").Trim().ToUpperInvariant();
        var d = await _db.Discounts.FirstOrDefaultAsync(x => x.DiscountCode != null && x.DiscountCode.ToUpper() == code);
        var today = OrderLogic.TodayIst();
        string? err = null;
        if (d == null || code.Length == 0) err = "Coupon code not found.";
        else if (!d.IsActive) err = "This coupon is inactive.";
        else if (d.ValidFrom != null && today < d.ValidFrom) err = $"This coupon is valid only from {d.ValidFrom:dd MMM yyyy}.";
        else if (d.ValidTo != null && today > d.ValidTo) err = $"This coupon expired on {d.ValidTo:dd MMM yyyy}.";
        else if (o.SubTotal + o.TaxAmount < d.MinOrderAmount) err = $"Minimum bill for this coupon is Rs {d.MinOrderAmount:N2}.";
        if (err != null) { TempData["Error"] = err; return RedirectToAction(nameof(Bill), new { id }); }

        o.DiscountId = d!.DiscountId; o.DiscountCode = d.DiscountCode;
        if (d.DiscountType.StartsWith("Percent", StringComparison.OrdinalIgnoreCase))
            o.DiscountPercent = Math.Min(100, d.DiscountValue);
        else { o.DiscountPercent = 0; o.DiscountAmount = Math.Min(d.DiscountValue, o.SubTotal + o.TaxAmount); }
        OrderLogic.Recalculate(o);
        if (o.PaidAmount > o.GrandTotal) { TempData["Error"] = "Coupon would make the bill less than what is already paid."; return RedirectToAction(nameof(Bill), new { id }); }
        await _db.SaveChangesAsync();
        TempData["Success"] = $"Coupon {d.DiscountCode} applied.";
        return RedirectToAction(nameof(Bill), new { id });
    }

    /// <summary>Records a payment. If the customer pays MORE than the due amount, the extra goes as a tip to the
    /// table bearer and is saved as a restaurant expense (type Tip) - it is never restaurant profit.</summary>
    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> RecordPayment(int id, string mode, decimal amount, string? reference, int? waiterEmployeeId)
    {
        var o = await LoadOrder(id);
        if (o == null) return NotFound();
        if (o.Status != OrderStatus.Open) { TempData["Error"] = "Bill is already closed."; return RedirectToAction(nameof(Bill), new { id }); }
        if (amount <= 0) { TempData["Error"] = "Enter the amount received."; return RedirectToAction(nameof(Bill), new { id }); }
        if (string.IsNullOrWhiteSpace(mode)) mode = "Cash";
        if (string.IsNullOrWhiteSpace(reference) && mode.Equals("UPI", StringComparison.OrdinalIgnoreCase))
            reference = o.CustomerUtr;

        var due = o.DueAmount;
        var tip = amount - due > 0.009m ? amount - due : 0m;
        var waiterId = waiterEmployeeId ?? o.WaiterEmployeeId;
        if (tip > 0 && waiterId == null)
        {
            TempData["Error"] = $"Customer paid Rs {tip:N2} more than the bill. Select the table bearer so the extra is saved as his / her tip.";
            return RedirectToAction(nameof(Bill), new { id });
        }

        o.Payments.Add(new OrderPayment
        {
            ModeName = mode, Amount = amount,
            ReferenceNo = string.IsNullOrWhiteSpace(reference) ? null : reference.Trim(),
            ReceivedBy = User.Identity?.Name
        });
        o.PaidAmount += amount - tip;
        if (tip > 0)
        {
            o.WaiterEmployeeId = waiterId;
            o.TipAmount += tip;
            _db.RestaurantExpenses.Add(new RestaurantExpense
            {
                DocNo = await OrderLogic.NextExpenseNo(_db),
                ExpenseType = ExpenseType.Tip,
                ExpenseDate = OrderLogic.TodayIst(),
                EmployeeId = waiterId,
                OrderId = o.OrderId,
                Description = $"Tip from bill {o.OrderNo} (customer paid extra)",
                SubTotal = tip, GrandTotal = tip, PaidAmount = tip,
                PaymentMode = mode, ReferenceNo = o.OrderNo,
                CreatedBy = User.Identity?.Name
            });
        }
        if (o.PaidAmount >= o.GrandTotal)
        {
            o.Status = OrderStatus.Paid;
            o.PaidOn = DateTime.UtcNow;
            await OrderLogic.ReleaseTableIfDone(_db, o);
        }
        await _db.SaveChangesAsync();
        TempData["Success"] = (o.Status == OrderStatus.Paid ? "Payment received. Bill closed." : "Part payment recorded.")
            + (tip > 0 ? $" Rs {tip:N2} extra saved as tip for the table bearer." : "");
        return RedirectToAction(nameof(Bill), new { id });
    }

    private Task<CustomerOrder?> LoadOrder(int id) =>
        _db.CustomerOrders.Include(o => o.Items).Include(o => o.Payments).Include(o => o.DiningTable).Include(o => o.WaiterEmployee)
            .FirstOrDefaultAsync(o => o.OrderId == id);

    private async Task<BillViewModel> BuildVm(CustomerOrder o)
    {
        var s = await _db.RestaurantSettings.FirstOrDefaultAsync() ?? new RestaurantSetting();
        var modes = await _db.PaymentModes.Where(p => p.IsActive).OrderBy(p => p.ModeName).Select(p => p.ModeName).ToListAsync();
        if (modes.Count == 0) modes = new List<string> { "Cash", "UPI", "Card" };

        var baseUrl = string.IsNullOrWhiteSpace(s.PublicBaseUrl) ? $"{Request.Scheme}://{Request.Host}" : s.PublicBaseUrl.TrimEnd('/');
        var payUrl = $"{baseUrl}/Pay/{o.PayToken}";
        var today = OrderLogic.TodayIst();
        var vm = new BillViewModel
        {
            Order = o, Setting = s, PaymentModes = modes, PayPageUrl = payUrl,
            Waiters = await PosController.LoadWaiters(_db),
            Coupons = await _db.Discounts.Where(d => d.IsActive && d.DiscountCode != null
                    && (d.ValidFrom == null || d.ValidFrom <= today) && (d.ValidTo == null || d.ValidTo >= today))
                .OrderBy(d => d.DiscountName).ToListAsync(),
            UpiLink = string.IsNullOrWhiteSpace(s.UpiId) ? "" : OrderLogic.BuildUpiLink(s, o, o.DueAmount)
        };
        if (o.CustomerMobile != null)
        {
            var msg = $"Hello {(o.CustomerName ?? "")}, your bill {o.OrderNo} at {s.RestaurantName} is Rs {o.DueAmount:N2}. Pay by UPI here: {payUrl}";
            vm.WhatsAppUrl = $"https://wa.me/91{o.CustomerMobile}?text={WebUtility.UrlEncode(msg)}";
            vm.SmsUrl = $"sms:+91{o.CustomerMobile}?body={WebUtility.UrlEncode(msg)}";
        }
        return vm;
    }
}
