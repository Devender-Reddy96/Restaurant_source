using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("discount_master", Schema = "billing")]
public class Discount : AuditEntity
{
    [Key]
    public int DiscountId { get; set; }

    [Display(Name = "Discount Name")]
    [Required(ErrorMessage = "Discount Name is required.")]
    [StringLength(100, ErrorMessage = "Discount Name can be at most 100 characters.")]
    public string DiscountName { get; set; } = string.Empty;

    [Display(Name = "Discount Code")]
    [StringLength(30, ErrorMessage = "Discount Code can be at most 30 characters.")]
    public string? DiscountCode { get; set; }

    [Display(Name = "Discount Type")]
    [Required(ErrorMessage = "Discount Type is required.")]
    [StringLength(30, ErrorMessage = "Discount Type can be at most 30 characters.")]
    public string DiscountType { get; set; } = "Percentage";

    [Display(Name = "Discount Value")]
    [Range(0, 99999999.99, ErrorMessage = "Discount Value must be between 0 and 99999999.99.")]
    [Column(TypeName = "numeric(12,2)")]
    public decimal DiscountValue { get; set; }

    [Display(Name = "Min Order Amount")]
    [Range(0, 99999999.99, ErrorMessage = "Min Order Amount must be between 0 and 99999999.99.")]
    [Column(TypeName = "numeric(12,2)")]
    public decimal MinOrderAmount { get; set; }

    [Display(Name = "Valid From")]
    public DateOnly? ValidFrom { get; set; }

    [Display(Name = "Valid To")]
    public DateOnly? ValidTo { get; set; }

}
