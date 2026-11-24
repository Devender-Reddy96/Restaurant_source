using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("designation_master", Schema = "hr")]
public class Designation : AuditEntity
{
    [Key]
    public int DesignationId { get; set; }

    [Display(Name = "Designation Name")]
    [Required(ErrorMessage = "Designation Name is required.")]
    [StringLength(100, ErrorMessage = "Designation Name can be at most 100 characters.")]
    public string DesignationName { get; set; } = string.Empty;

    [Display(Name = "Description")]
    [StringLength(200, ErrorMessage = "Description can be at most 200 characters.")]
    public string? Description { get; set; }

}
