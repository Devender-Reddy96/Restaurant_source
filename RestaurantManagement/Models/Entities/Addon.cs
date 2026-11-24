using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("addon_master", Schema = "menu")]
public class Addon : AuditEntity
{
    [Key]
    public int AddonId { get; set; }

    [Display(Name = "Add-on Name")]
    [Required(ErrorMessage = "Add-on Name is required.")]
    [StringLength(100, ErrorMessage = "Add-on Name can be at most 100 characters.")]
    public string AddonName { get; set; } = string.Empty;

    [Display(Name = "Price")]
    [Range(0, 99999999.99, ErrorMessage = "Price must be between 0 and 99999999.99.")]
    [Column(TypeName = "numeric(12,2)")]
    public decimal Price { get; set; }

}
