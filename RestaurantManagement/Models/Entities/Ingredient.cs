using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("ingredient_master", Schema = "inventory")]
public class Ingredient : AuditEntity
{
    [Key]
    public int IngredientId { get; set; }

    [Display(Name = "Ingredient Name")]
    [Required(ErrorMessage = "Ingredient Name is required.")]
    [StringLength(100, ErrorMessage = "Ingredient Name can be at most 100 characters.")]
    public string IngredientName { get; set; } = string.Empty;

    [Display(Name = "Unit")]
    public int UnitId { get; set; }
    [ValidateNever]
    public Unit? Unit { get; set; }

    [Display(Name = "Reorder Level")]
    [Range(0, 99999999.99, ErrorMessage = "Reorder Level must be between 0 and 99999999.99.")]
    [Column(TypeName = "numeric(12,2)")]
    public decimal ReorderLevel { get; set; }

    [Display(Name = "Cost Per Unit")]
    [Range(0, 99999999.99, ErrorMessage = "Cost Per Unit must be between 0 and 99999999.99.")]
    [Column(TypeName = "numeric(12,2)")]
    public decimal CostPerUnit { get; set; }

}
