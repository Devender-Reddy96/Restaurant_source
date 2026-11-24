using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models;
using RestaurantManagement.Models.Entities;
using RestaurantManagement.Services;

namespace RestaurantManagement.Controllers;

/// <summary>Public page the customer opens from the WhatsApp / SMS link. Identified only by the unguessable token.</summary>
[AllowAnonymous]
public class PayController : Controller
{
    private readonly AppDbContext _db;
    public PayController(AppDbContext db) => _db = db;

    [HttpGet("Pay/{token:guid}")]
    public async Task<IActionResult> Index(Guid token)
    {
        var o = await _db.CustomerOrders.Include(x => x.Items).FirstOrDefaultAsync(x => x.PayToken == token);
        if (o == null || o.Status == OrderStatus.Cancelled) return NotFound();
        var s = await _db.RestaurantSettings.FirstOrDefaultAsync() ?? new RestaurantSetting();
        var due = o.DueAmount;
        return View(new PayPageViewModel
        {
            Order = o, Setting = s,
            UpiLink = OrderLogic.BuildUpiLink(s, o, due),
            GPayLink = OrderLogic.BuildUpiLink(s, o, due, "tez://upi/pay"),
            PhonePeLink = OrderLogic.BuildUpiLink(s, o, due, "phonepe://pay"),
            PaytmLink = OrderLogic.BuildUpiLink(s, o, due, "paytmmp://pay")
        });
    }

    /// <summary>Customer types the UPI transaction id after paying; staff verifies it on the bill screen.</summary>
    [HttpPost("Pay/{token:guid}/utr"), ValidateAntiForgeryToken]
    public async Task<IActionResult> Utr(Guid token, string? utr)
    {
        var o = await _db.CustomerOrders.FirstOrDefaultAsync(x => x.PayToken == token);
        if (o == null) return NotFound();
        utr = utr?.Trim();
        if (!string.IsNullOrEmpty(utr) && utr.Length is >= 6 and <= 40 && utr.All(char.IsLetterOrDigit))
        {
            o.CustomerUtr = utr;
            await _db.SaveChangesAsync();
            TempData["Success"] = "Thank you! The cashier will confirm your payment shortly.";
        }
        else TempData["Error"] = "Enter the 12-digit UPI reference number shown in your payment app.";
        return Redirect($"/Pay/{token}");
    }
}
