using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

[Table("employee_master", Schema = "hr")]
public class Employee : AuditEntity
{
    [Key]
    public int EmployeeId { get; set; }

    [Display(Name = "Employee Code")]
    [Required(ErrorMessage = "Employee Code is required.")]
    [StringLength(20, ErrorMessage = "Employee Code can be at most 20 characters.")]
    public string EmployeeCode { get; set; } = string.Empty;

    [Display(Name = "Full Name")]
    [Required(ErrorMessage = "Full Name is required.")]
    [StringLength(100, ErrorMessage = "Full Name can be at most 100 characters.")]
    public string FullName { get; set; } = string.Empty;

    [Display(Name = "Designation")]
    public int DesignationId { get; set; }
    [ValidateNever]
    public Designation? Designation { get; set; }

    [Display(Name = "Shift")]
    public int? ShiftId { get; set; }
    [ValidateNever]
    public Shift? Shift { get; set; }

    [Display(Name = "Branch")]
    public int? BranchId { get; set; }
    [ValidateNever]
    public Branch? Branch { get; set; }

    [Display(Name = "Phone")]
    [StringLength(20, ErrorMessage = "Phone can be at most 20 characters.")]
    public string? Phone { get; set; }

    [Display(Name = "Email")]
    [StringLength(100, ErrorMessage = "Email can be at most 100 characters.")]
    [EmailAddress(ErrorMessage = "Enter a valid email address.")]
    public string? Email { get; set; }

    [Display(Name = "Gender")]
    [StringLength(30, ErrorMessage = "Gender can be at most 30 characters.")]
    public string? Gender { get; set; }

    [Display(Name = "Date Of Birth")]
    public DateOnly? DateOfBirth { get; set; }

    [Display(Name = "Joining Date")]
    public DateOnly? JoiningDate { get; set; }

    [Display(Name = "Monthly Salary")]
    [Range(0, 99999999.99, ErrorMessage = "Monthly Salary must be between 0 and 99999999.99.")]
    [Column(TypeName = "numeric(12,2)")]
    public decimal? Salary { get; set; }

    [Display(Name = "Address")]
    [StringLength(1000, ErrorMessage = "Address can be at most 1000 characters.")]
    public string? Address { get; set; }

}
