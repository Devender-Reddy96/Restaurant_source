using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("customer_master", Schema = "crm")]
public class Customer : AuditEntity
{
    [Key]
    public int CustomerId { get; set; }

    [Display(Name = "Customer Name")]
    [Required(ErrorMessage = "Customer Name is required.")]
    [StringLength(100, ErrorMessage = "Customer Name can be at most 100 characters.")]
    public string CustomerName { get; set; } = string.Empty;

    [Display(Name = "Phone")]
    [Required(ErrorMessage = "Phone is required.")]
    [StringLength(20, ErrorMessage = "Phone can be at most 20 characters.")]
    public string Phone { get; set; } = string.Empty;

    [Display(Name = "Email")]
    [StringLength(100, ErrorMessage = "Email can be at most 100 characters.")]
    [EmailAddress(ErrorMessage = "Enter a valid email address.")]
    public string? Email { get; set; }

    [Display(Name = "Birth Date")]
    public DateOnly? BirthDate { get; set; }

    [Display(Name = "Loyalty Points")]
    [Range(0, 1000000, ErrorMessage = "Loyalty Points must be zero or more.")]
    public int LoyaltyPoints { get; set; }

    [Display(Name = "Address")]
    [StringLength(1000, ErrorMessage = "Address can be at most 1000 characters.")]
    public string? Address { get; set; }

}
