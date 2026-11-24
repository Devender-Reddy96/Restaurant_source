using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("kitchen_station", Schema = "orders")]
public class KitchenStation : AuditEntity
{
    [Key]
    public int KitchenStationId { get; set; }

    [Display(Name = "Station Name")]
    [Required(ErrorMessage = "Station Name is required.")]
    [StringLength(100, ErrorMessage = "Station Name can be at most 100 characters.")]
    public string StationName { get; set; } = string.Empty;

    [Display(Name = "Printer Name")]
    [StringLength(100, ErrorMessage = "Printer Name can be at most 100 characters.")]
    public string? PrinterName { get; set; }

    [Display(Name = "Description")]
    [StringLength(200, ErrorMessage = "Description can be at most 200 characters.")]
    public string? Description { get; set; }

}
