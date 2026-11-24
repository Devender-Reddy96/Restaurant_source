using System.ComponentModel.DataAnnotations;

namespace RestaurantManagement.Models;

public class LoginViewModel
{
    [Required(ErrorMessage = "Enter your user name.")]
    [Display(Name = "User name")]
    public string UserName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Enter your password.")]
    [DataType(DataType.Password)]
    public string Password { get; set; } = string.Empty;

    [Display(Name = "Keep me signed in")]
    public bool RememberMe { get; set; }

    public string? ReturnUrl { get; set; }
}

public class UserFormViewModel
{
    public int UserId { get; set; }

    [Required(ErrorMessage = "User name is required.")]
    [StringLength(50)]
    [Display(Name = "User Name")]
    public string UserName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Full name is required.")]
    [StringLength(100)]
    [Display(Name = "Full Name")]
    public string FullName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Role is required.")]
    [Display(Name = "Role")]
    public int? RoleId { get; set; }

    [Display(Name = "Branch")]
    public int? BranchId { get; set; }

    [DataType(DataType.Password)]
    [StringLength(100, MinimumLength = 6, ErrorMessage = "Password must be at least 6 characters.")]
    public string? Password { get; set; }

    [Display(Name = "Active")]
    public bool IsActive { get; set; } = true;
}

public class NameCount
{
    public string Name { get; set; } = string.Empty;
    public int Count { get; set; }
}

public class DashboardViewModel
{
    public int Categories { get; set; }
    public int FoodItems { get; set; }
    public int Tables { get; set; }
    public int Staff { get; set; }
    public int Suppliers { get; set; }
    public int Customers { get; set; }
    public List<NameCount> TableStatus { get; set; } = new();
    public List<NameCount> ItemsByCategory { get; set; } = new();
    public List<Entities.FoodItem> RecentItems { get; set; } = new();
}
