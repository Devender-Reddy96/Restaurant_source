using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("supplier_master", Schema = "purchase")]
public class Supplier : AuditEntity
{
    [Key]
    public int SupplierId { get; set; }

    [Display(Name = "Supplier Name")]
    [Required(ErrorMessage = "Supplier Name is required.")]
    [StringLength(150, ErrorMessage = "Supplier Name can be at most 150 characters.")]
    public string SupplierName { get; set; } = string.Empty;

    [Display(Name = "Contact Person")]
    [StringLength(100, ErrorMessage = "Contact Person can be at most 100 characters.")]
    public string? ContactPerson { get; set; }

    [Display(Name = "Phone")]
    [StringLength(20, ErrorMessage = "Phone can be at most 20 characters.")]
    public string? Phone { get; set; }

    [Display(Name = "Email")]
    [StringLength(100, ErrorMessage = "Email can be at most 100 characters.")]
    [EmailAddress(ErrorMessage = "Enter a valid email address.")]
    public string? Email { get; set; }

    [Display(Name = "GST Number")]
    [StringLength(20, ErrorMessage = "GST Number can be at most 20 characters.")]
    public string? GstNumber { get; set; }

    [Display(Name = "Address")]
    [StringLength(1000, ErrorMessage = "Address can be at most 1000 characters.")]
    public string? Address { get; set; }

}
