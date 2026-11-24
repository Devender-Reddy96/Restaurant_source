namespace RestaurantManagement.Models.Entities;

public abstract class AuditEntity
{
    public bool IsActive { get; set; } = true;
    public DateTime CreatedOn { get; set; } = DateTime.UtcNow;
}
