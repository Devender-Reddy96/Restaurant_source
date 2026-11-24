using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Data;
using RestaurantManagement.Models;
using RestaurantManagement.Services;

namespace RestaurantManagement.Controllers;

[AllowAnonymous]
public class AccountController : Controller
{
    private readonly AppDbContext _db;
    public AccountController(AppDbContext db) => _db = db;

    [HttpGet]
    public IActionResult Login(string? returnUrl = null)
    {
        if (User.Identity?.IsAuthenticated == true) return RedirectToAction("Index", "Home");
        return View(new LoginViewModel { ReturnUrl = returnUrl });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Login(LoginViewModel m)
    {
        if (!ModelState.IsValid) return View(m);

        var user = await _db.Users.Include(u => u.Role)
            .FirstOrDefaultAsync(u => u.UserName == m.UserName.Trim() && u.IsActive);

        if (user == null || user.Role == null || !PasswordHasher.Verify(m.Password, user.PasswordHash))
        {
            ModelState.AddModelError("", "Invalid user name or password.");
            return View(m);
        }

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.UserId.ToString()),
            new(ClaimTypes.Name, user.UserName),
            new("FullName", user.FullName),
            new(ClaimTypes.Role, user.Role.RoleName)
        };
        var principal = new ClaimsPrincipal(new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme));
        await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal,
            new AuthenticationProperties { IsPersistent = m.RememberMe });

        user.LastLoginOn = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        if (!string.IsNullOrEmpty(m.ReturnUrl) && Url.IsLocalUrl(m.ReturnUrl)) return Redirect(m.ReturnUrl);
        return RedirectToAction("Index", "Home");
    }

    [HttpPost, ValidateAntiForgeryToken, Authorize]
    public async Task<IActionResult> Logout()
    {
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return RedirectToAction(nameof(Login));
    }

    public IActionResult AccessDenied() => View();
}
