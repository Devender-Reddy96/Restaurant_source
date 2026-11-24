using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RestaurantManagement.Models.Entities;

[Table("user_master", Schema = "admin")]
public class AppUser : AuditEntity
{
    [Key]
    public int UserId { get; set; }
    public string UserName { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public int RoleId { get; set; }
    public Role? Role { get; set; }
    public int? BranchId { get; set; }
    public Branch? Branch { get; set; }
    public DateTime? LastLoginOn { get; set; }
}
