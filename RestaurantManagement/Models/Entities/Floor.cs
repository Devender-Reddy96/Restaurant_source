using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("floor_master", Schema = "orders")]
public class Floor : AuditEntity
{
    [Key]
    public int FloorId { get; set; }

    [Display(Name = "Floor / Area Name")]
    [Required(ErrorMessage = "Floor / Area Name is required.")]
    [StringLength(100, ErrorMessage = "Floor / Area Name can be at most 100 characters.")]
    public string FloorName { get; set; } = string.Empty;

    [Display(Name = "Branch")]
    public int? BranchId { get; set; }
    [ValidateNever]
    public Branch? Branch { get; set; }

    [Display(Name = "Description")]
    [StringLength(200, ErrorMessage = "Description can be at most 200 characters.")]
    public string? Description { get; set; }

}
