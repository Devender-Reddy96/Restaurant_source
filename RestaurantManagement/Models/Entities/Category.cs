using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("category_master", Schema = "menu")]
public class Category : AuditEntity
{
    [Key]
    public int CategoryId { get; set; }

    [Display(Name = "Category Name")]
    [Required(ErrorMessage = "Category Name is required.")]
    [StringLength(100, ErrorMessage = "Category Name can be at most 100 characters.")]
    public string CategoryName { get; set; } = string.Empty;

    [Display(Name = "Description")]
    [StringLength(200, ErrorMessage = "Description can be at most 200 characters.")]
    public string? Description { get; set; }

    [Display(Name = "Display Order")]
    [Range(0, 1000000, ErrorMessage = "Display Order must be zero or more.")]
    public int DisplayOrder { get; set; }

}
