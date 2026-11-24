using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("unit_master", Schema = "inventory")]
public class Unit : AuditEntity
{
    [Key]
    public int UnitId { get; set; }

    [Display(Name = "Unit Name")]
    [Required(ErrorMessage = "Unit Name is required.")]
    [StringLength(50, ErrorMessage = "Unit Name can be at most 50 characters.")]
    public string UnitName { get; set; } = string.Empty;

    [Display(Name = "Short Name")]
    [Required(ErrorMessage = "Short Name is required.")]
    [StringLength(10, ErrorMessage = "Short Name can be at most 10 characters.")]
    public string ShortName { get; set; } = string.Empty;

}
