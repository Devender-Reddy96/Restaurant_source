using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("table_master", Schema = "orders")]
public class DiningTable : AuditEntity
{
    [Key]
    public int DiningTableId { get; set; }

    [Display(Name = "Floor / Area")]
    public int FloorId { get; set; }
    [ValidateNever]
    public Floor? Floor { get; set; }

    [Display(Name = "Table Number")]
    [Required(ErrorMessage = "Table Number is required.")]
    [StringLength(20, ErrorMessage = "Table Number can be at most 20 characters.")]
    public string TableNumber { get; set; } = string.Empty;

    [Display(Name = "Seating Capacity")]
    [Range(0, 1000000, ErrorMessage = "Seating Capacity must be zero or more.")]
    public int Capacity { get; set; } = 4;

    [Display(Name = "Status")]
    [Required(ErrorMessage = "Status is required.")]
    [StringLength(30, ErrorMessage = "Status can be at most 30 characters.")]
    public string Status { get; set; } = "Available";

}
