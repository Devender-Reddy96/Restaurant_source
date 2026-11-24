using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("payment_mode_master", Schema = "payments")]
public class PaymentMode : AuditEntity
{
    [Key]
    public int PaymentModeId { get; set; }

    [Display(Name = "Mode Name")]
    [Required(ErrorMessage = "Mode Name is required.")]
    [StringLength(50, ErrorMessage = "Mode Name can be at most 50 characters.")]
    public string ModeName { get; set; } = string.Empty;

    [Display(Name = "Mode Type")]
    [Required(ErrorMessage = "Mode Type is required.")]
    [StringLength(30, ErrorMessage = "Mode Type can be at most 30 characters.")]
    public string ModeType { get; set; } = "Cash";

    [Display(Name = "Needs Reference No.")]
    public bool RequiresReference { get; set; }

}
