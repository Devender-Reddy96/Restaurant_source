using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("tax_master", Schema = "billing")]
public class Tax : AuditEntity
{
    [Key]
    public int TaxId { get; set; }

    [Display(Name = "Tax Name")]
    [Required(ErrorMessage = "Tax Name is required.")]
    [StringLength(100, ErrorMessage = "Tax Name can be at most 100 characters.")]
    public string TaxName { get; set; } = string.Empty;

    [Display(Name = "Tax %")]
    [Range(0, 100.0, ErrorMessage = "Tax % must be between 0 and 100.0.")]
    [Column(TypeName = "numeric(12,2)")]
    public decimal TaxPercentage { get; set; }

    [Display(Name = "Price Inclusive of Tax")]
    public bool IsInclusive { get; set; }

}
