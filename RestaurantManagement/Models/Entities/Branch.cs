using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("branch_master", Schema = "admin")]
public class Branch : AuditEntity
{
    [Key]
    public int BranchId { get; set; }

    [Display(Name = "Branch Name")]
    [Required(ErrorMessage = "Branch Name is required.")]
    [StringLength(100, ErrorMessage = "Branch Name can be at most 100 characters.")]
    public string BranchName { get; set; } = string.Empty;

    [Display(Name = "Branch Code")]
    [Required(ErrorMessage = "Branch Code is required.")]
    [StringLength(20, ErrorMessage = "Branch Code can be at most 20 characters.")]
    public string BranchCode { get; set; } = string.Empty;

    [Display(Name = "Phone")]
    [StringLength(20, ErrorMessage = "Phone can be at most 20 characters.")]
    public string? Phone { get; set; }

    [Display(Name = "Email")]
    [StringLength(100, ErrorMessage = "Email can be at most 100 characters.")]
    [EmailAddress(ErrorMessage = "Enter a valid email address.")]
    public string? Email { get; set; }

    [Display(Name = "City")]
    [StringLength(60, ErrorMessage = "City can be at most 60 characters.")]
    public string? City { get; set; }

    [Display(Name = "State")]
    [StringLength(60, ErrorMessage = "State can be at most 60 characters.")]
    public string? State { get; set; }

    [Display(Name = "Pincode")]
    [StringLength(10, ErrorMessage = "Pincode can be at most 10 characters.")]
    public string? Pincode { get; set; }

    [Display(Name = "GST Number")]
    [StringLength(20, ErrorMessage = "GST Number can be at most 20 characters.")]
    public string? GstNumber { get; set; }

    [Display(Name = "FSSAI Number")]
    [StringLength(20, ErrorMessage = "FSSAI Number can be at most 20 characters.")]
    public string? FssaiNumber { get; set; }

    [Display(Name = "Address")]
    [StringLength(1000, ErrorMessage = "Address can be at most 1000 characters.")]
    public string? Address { get; set; }

}
