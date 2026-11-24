using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("expense_category_master", Schema = "expense")]
public class ExpenseCategory : AuditEntity
{
    [Key]
    public int ExpenseCategoryId { get; set; }

    [Display(Name = "Category Name")]
    [Required(ErrorMessage = "Category Name is required.")]
    [StringLength(100, ErrorMessage = "Category Name can be at most 100 characters.")]
    public string ExpenseCategoryName { get; set; } = string.Empty;

    [Display(Name = "Description")]
    [StringLength(200, ErrorMessage = "Description can be at most 200 characters.")]
    public string? Description { get; set; }

}
