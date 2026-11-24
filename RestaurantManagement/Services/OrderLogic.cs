using System.Net;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Services;

public static class OrderLogic
{
    public static DateTime ToIst(DateTime utc) =>
        DateTime.SpecifyKind(utc, DateTimeKind.Utc).AddHours(5).AddMinutes(30);

    public static string? CleanMobile(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return null;
        var d = new string(raw.Where(char.IsDigit).ToArray());
        if (d.Length == 12 && d.StartsWith("91")) d = d[2..];
        if (d.Length == 11 && d.StartsWith("0")) d = d[1..];
        return d.Length == 10 ? d : null;
    }

    /// <summary>Fills base / tax / total of one line from the menu price and tax master.</summary>
    public static void PriceLine(OrderItem it)
    {
        var gross = (it.UnitPrice + it.AddonUnitPrice) * it.Quantity;
        if (it.TaxInclusive)
        {
            it.TaxAmount = Math.Round(gross * it.TaxPercent / (100 + it.TaxPercent), 2);
            it.LineTotal = gross;
            it.LineBase = gross - it.TaxAmount;
        }
        else
        {
            it.LineBase = gross;
            it.TaxAmount = Math.Round(gross * it.TaxPercent / 100, 2);
            it.LineTotal = gross + it.TaxAmount;
        }
    }

    /// <summary>Recomputes order totals from the non-cancelled lines. Items must be loaded.</summary>
    public static void Recalculate(CustomerOrder o)
    {
        var live = o.Items.Where(i => i.Status != ItemStatus.Cancelled).ToList();
        o.SubTotal = live.Sum(i => i.LineBase);
        o.TaxAmount = live.Sum(i => i.TaxAmount);
        // A % discount / coupon follows the bill when items are added or cancelled.
        if (o.DiscountPercent > 0)
            o.DiscountAmount = Math.Round((o.SubTotal + o.TaxAmount) * o.DiscountPercent / 100, 2);
        if (o.DiscountAmount > o.SubTotal + o.TaxAmount) o.DiscountAmount = o.SubTotal + o.TaxAmount;
        var gross = o.SubTotal + o.TaxAmount - o.DiscountAmount;
        if (gross < 0) gross = 0;
        var rounded = Math.Round(gross, 0, MidpointRounding.AwayFromZero);
        o.RoundOff = rounded - gross;
        o.GrandTotal = rounded;
    }

    /// <summary>Frees the table once the bill is paid AND every item is served / cancelled.</summary>
    public static async Task ReleaseTableIfDone(AppDbContext db, CustomerOrder o)
    {
        if (o.Status != OrderStatus.Paid || o.DiningTableId == null) return;
        if (o.Items.Any(i => i.Status is ItemStatus.New or ItemStatus.Preparing or ItemStatus.Ready)) return;
        var otherOpen = await db.CustomerOrders.AnyAsync(x =>
            x.DiningTableId == o.DiningTableId && x.OrderId != o.OrderId && x.Status == OrderStatus.Open);
        if (otherOpen) return;
        var t = await db.DiningTables.FindAsync(o.DiningTableId);
        if (t != null) t.Status = "Available";
    }

    /// <summary>Today's date in India.</summary>
    public static DateOnly TodayIst() => DateOnly.FromDateTime(ToIst(DateTime.UtcNow));

    /// <summary>UTC instant of 00:00 IST on the given date (for timestamptz filters).</summary>
    public static DateTime IstStartUtc(DateOnly d) =>
        DateTime.SpecifyKind(d.ToDateTime(TimeOnly.MinValue).AddHours(-5).AddMinutes(-30), DateTimeKind.Utc);

    public static async Task<string> NextExpenseNo(AppDbContext db)
    {
        var seq = await db.Database.SqlQuery<long>($"SELECT nextval('expense.restaurant_expense_no_seq') AS \"Value\"").SingleAsync();
        return "EXP-" + seq;
    }

    public static string BuildUpiLink(RestaurantSetting s, CustomerOrder o, decimal amount, string scheme = "upi://pay")
    {
        var pn = WebUtility.UrlEncode(string.IsNullOrWhiteSpace(s.UpiPayeeName) ? s.RestaurantName : s.UpiPayeeName);
        var tn = WebUtility.UrlEncode("Bill " + o.OrderNo);
        return $"{scheme}?pa={WebUtility.UrlEncode(s.UpiId ?? "")}&pn={pn}&am={amount:0.00}&cu=INR&tn={tn}";
    }
}
