using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("food_item_master", Schema = "menu")]
public class FoodItem : AuditEntity
{
    [Key]
    public int FoodItemId { get; set; }

    [Display(Name = "Photo")]
    [StringLength(500, ErrorMessage = "Photo can be at most 500 characters.")]
    public string? ImagePath { get; set; }

    [Display(Name = "Image Source (Wikipedia page title)")]
    [StringLength(200)]
    public string? ImageSource { get; set; }

    [Display(Name = "Item Code")]
    [StringLength(20, ErrorMessage = "Item Code can be at most 20 characters.")]
    public string? ItemCode { get; set; }

    [Display(Name = "Food Name")]
    [Required(ErrorMessage = "Food Name is required.")]
    [StringLength(150, ErrorMessage = "Food Name can be at most 150 characters.")]
    public string FoodName { get; set; } = string.Empty;

    [Display(Name = "Category")]
    public int CategoryId { get; set; }
    [ValidateNever]
    public Category? Category { get; set; }

    [Display(Name = "Food Type")]
    [Required(ErrorMessage = "Food Type is required.")]
    [StringLength(30, ErrorMessage = "Food Type can be at most 30 characters.")]
    public string FoodType { get; set; } = "Veg";

    [Display(Name = "Price")]
    [Range(0, 99999999.99, ErrorMessage = "Price must be between 0 and 99999999.99.")]
    [Column(TypeName = "numeric(12,2)")]
    public decimal Price { get; set; }

    [Display(Name = "Tax")]
    public int? TaxId { get; set; }
    [ValidateNever]
    public Tax? Tax { get; set; }

    [Display(Name = "Kitchen Station")]
    public int? KitchenStationId { get; set; }
    [ValidateNever]
    public KitchenStation? KitchenStation { get; set; }

    [Display(Name = "Preparation Time (min)")]
    [Range(0, 1000000, ErrorMessage = "Preparation Time (min) must be zero or more.")]
    public int? PreparationTime { get; set; }

    [Display(Name = "Description")]
    [StringLength(1000, ErrorMessage = "Description can be at most 1000 characters.")]
    public string? Description { get; set; }

    [Display(Name = "Available for Sale")]
    public bool IsAvailable { get; set; } = true;

}
