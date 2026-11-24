using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("shift_master", Schema = "hr")]
public class Shift : AuditEntity
{
    [Key]
    public int ShiftId { get; set; }

    [Display(Name = "Shift Name")]
    [Required(ErrorMessage = "Shift Name is required.")]
    [StringLength(100, ErrorMessage = "Shift Name can be at most 100 characters.")]
    public string ShiftName { get; set; } = string.Empty;

    [Display(Name = "Start Time")]
    public TimeOnly StartTime { get; set; }

    [Display(Name = "End Time")]
    public TimeOnly EndTime { get; set; }

}
