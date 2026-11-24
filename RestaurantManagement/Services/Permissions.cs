using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Services;

public enum Right { View, Add, Edit, Delete }

public record AppModule(string Key, string Title, string Group, string Icon);

/// <summary>Every screen ("document") that can be granted to a user. Key = controller name.</summary>
public static class ModuleCatalog
{
    public static readonly List<AppModule> All = new()
    {
        new("Pos", "Tables & Orders", "Operations", "bi-grid-3x3-gap-fill"),
        new("Kitchen", "Kitchen Display", "Operations", "bi-fire"),
        new("Waiter", "Waiter / Bearer", "Operations", "bi-bell"),
        new("Billing", "Billing & Payments", "Operations", "bi-receipt"),
        new("Expenses", "Restaurant Expenses (Ingredients / Expenses / Tips)", "Finance", "bi-journal-minus"),
        new("Reports", "Profit & Loss Dashboard", "Finance", "bi-graph-up-arrow"),
        new("ExpenseCategories", "Expense Categories", "Finance", "bi-wallet2"),
        new("Categories", "Food Categories", "Menu", "bi-tags"),
        new("FoodItems", "Food Items", "Menu", "bi-egg-fried"),
        new("Addons", "Add-ons", "Menu", "bi-plus-circle"),
        new("MenuImages", "Menu Images", "Menu", "bi-images"),
        new("Floors", "Floors & Areas", "Dining", "bi-layers"),
        new("DiningTables", "Tables", "Dining", "bi-grid-3x3-gap"),
        new("KitchenStations", "Kitchen Stations", "Dining", "bi-fire"),
        new("Employees", "Staff / Employees", "Staff", "bi-people"),
        new("Designations", "Designations", "Staff", "bi-award"),
        new("Shifts", "Shifts", "Staff", "bi-clock"),
        new("Customers", "Customers", "Customers", "bi-person-heart"),
        new("Suppliers", "Suppliers", "Stock & Purchase", "bi-truck"),
        new("Units", "Units of Measure", "Stock & Purchase", "bi-rulers"),
        new("Ingredients", "Ingredients", "Stock & Purchase", "bi-basket"),
        new("Taxes", "Taxes", "Billing", "bi-percent"),
        new("Discounts", "Discounts & Coupons", "Billing", "bi-ticket-perforated"),
        new("PaymentModes", "Payment Modes", "Billing", "bi-credit-card"),
        new("RestaurantSettings", "Restaurant & UPI Settings", "Billing", "bi-qr-code"),
        new("Branches", "Branches", "Administration", "bi-shop"),
    };

    public static AppModule? ForController(string controller) =>
        All.FirstOrDefault(m => string.Equals(m.Key, controller, StringComparison.OrdinalIgnoreCase));

    /// <summary>Which right an action needs. Everything else only needs View.</summary>
    public static Right RightFor(string action)
    {
        bool S(params string[] p) => p.Any(x => action.StartsWith(x, StringComparison.OrdinalIgnoreCase));
        if (S("Delete", "Cancel", "Remove")) return Right.Delete;
        if (S("Create", "Add", "Place")) return Right.Add;
        if (S("Edit", "Set", "Update", "Record", "Apply", "Save", "Fetch")) return Right.Edit;
        return Right.View;
    }

    /// <summary>Starting permissions for a new user, by role. The Administrator can change them any time.</summary>
    public static List<UserPermission> RoleDefaults(string role, int userId)
    {
        UserPermission P(string k, bool a, bool e, bool d) =>
            new() { UserId = userId, ModuleKey = k, CanView = true, CanAdd = a, CanEdit = e, CanDelete = d };
        return role switch
        {
            "Manager" => All.Where(m => m.Key != "Branches").Select(m => P(m.Key, true, true, true)).ToList(),
            "Cashier" => new() { P("Pos", true, true, false), P("Billing", true, true, false), P("Expenses", true, false, false), P("Customers", true, true, false) },
            "Waiter" => new() { P("Pos", true, true, false), P("Waiter", true, true, false) },
            "Chef" => new() { P("Kitchen", true, true, false) },
            _ => new()
        };
    }
}

/// <summary>Loads the signed-in user's permissions once per request.</summary>
public class PermissionService
{
    private readonly AppDbContext _db;
    private readonly IHttpContextAccessor _http;
    private Dictionary<string, UserPermission>? _cache;

    public PermissionService(AppDbContext db, IHttpContextAccessor http) { _db = db; _http = http; }

    private ClaimsPrincipal? User => _http.HttpContext?.User;
    public bool IsAdmin => User?.IsInRole("Admin") == true;

    public async Task<Dictionary<string, UserPermission>> AllAsync()
    {
        if (_cache != null) return _cache;
        _cache = new(StringComparer.OrdinalIgnoreCase);
        if (int.TryParse(User?.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var uid))
        {
            foreach (var p in await _db.UserPermissions.AsNoTracking().Where(p => p.UserId == uid).ToListAsync())
                _cache[p.ModuleKey] = p;
        }
        return _cache;
    }

    public async Task<bool> HasAsync(string module, Right right = Right.View)
    {
        if (IsAdmin) return true;
        var all = await AllAsync();
        if (!all.TryGetValue(module, out var p) || !p.CanView) return false;
        return right switch { Right.Add => p.CanAdd, Right.Edit => p.CanEdit, Right.Delete => p.CanDelete, _ => true };
    }
}

/// <summary>Global filter: every screen in ModuleCatalog checks the user's permission. Administrator always passes.</summary>
public class PermissionFilter : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(ActionExecutingContext ctx, ActionExecutionDelegate next)
    {
        var user = ctx.HttpContext.User;
        if (user.Identity?.IsAuthenticated != true || user.IsInRole("Admin")
            || ctx.ActionDescriptor is not ControllerActionDescriptor cad)
        { await next(); return; }

        var module = ModuleCatalog.ForController(cad.ControllerName);
        if (module == null) { await next(); return; }

        var perms = ctx.HttpContext.RequestServices.GetRequiredService<PermissionService>();
        var need = ModuleCatalog.RightFor(cad.ActionName);
        if (await perms.HasAsync(module.Key, need)) { await next(); return; }

        var req = ctx.HttpContext.Request;
        var ajax = req.Headers["X-Requested-With"].Count > 0 || (req.ContentType ?? "").Contains("json");
        ctx.Result = ajax
            ? new JsonResult(new { ok = false, message = $"You do not have {need} permission for {module.Title}." }) { StatusCode = 403 }
            : new RedirectToActionResult("AccessDenied", "Account", null);
    }
}
