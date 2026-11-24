using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("role_master", Schema = "admin")]
public class Role : AuditEntity
{
    [Key]
    public int RoleId { get; set; }

    [Display(Name = "Role Name")]
    [Required(ErrorMessage = "Role Name is required.")]
    [StringLength(50, ErrorMessage = "Role Name can be at most 50 characters.")]
    public string RoleName { get; set; } = string.Empty;

    [Display(Name = "Description")]
    [StringLength(200, ErrorMessage = "Description can be at most 200 characters.")]
    public string? Description { get; set; }

}
