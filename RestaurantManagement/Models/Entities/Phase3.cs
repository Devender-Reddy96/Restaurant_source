using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

public static class ExpenseType
{
    public const string Ingredient = "Ingredient", Expense = "Expense", Tip = "Tip";
    public static readonly string[] All = { Ingredient, Expense, Tip };
}

/// <summary>Restaurant expense document: ingredient bill from a supplier, a general expense, or a waiter tip.
/// It is money going OUT of the restaurant - never profit.</summary>
[Table("restaurant_expense", Schema = "expense")]
public class RestaurantExpense
{
    [Key]
    public int RestaurantExpenseId { get; set; }
    public string DocNo { get; set; } = string.Empty;
    public string ExpenseType { get; set; } = Entities.ExpenseType.Ingredient;
    public DateOnly ExpenseDate { get; set; }
    public int? SupplierId { get; set; }
    [ValidateNever] public Supplier? Supplier { get; set; }
    public int? ExpenseCategoryId { get; set; }
    [ValidateNever] public ExpenseCategory? ExpenseCategory { get; set; }
    public int? EmployeeId { get; set; }
    [ValidateNever] public Employee? Employee { get; set; }
    public int? OrderId { get; set; }
    public string? BillNo { get; set; }
    public string? Description { get; set; }
    [Column(TypeName = "numeric(12,2)")] public decimal SubTotal { get; set; }
    [Column(TypeName = "numeric(6,2)")] public decimal TaxPercent { get; set; }
    [Column(TypeName = "numeric(12,2)")] public decimal TaxAmount { get; set; }
    [Column(TypeName = "numeric(6,2)")] public decimal DiscountPercent { get; set; }
    [Column(TypeName = "numeric(12,2)")] public decimal DiscountAmount { get; set; }
    [Column(TypeName = "numeric(12,2)")] public decimal GrandTotal { get; set; }
    [Column(TypeName = "numeric(12,2)")] public decimal PaidAmount { get; set; }
    public string? PaymentMode { get; set; }
    public string? ReferenceNo { get; set; }
    public string? CreatedBy { get; set; }
    public DateTime CreatedOn { get; set; } = DateTime.UtcNow;
    public List<RestaurantExpenseItem> Items { get; set; } = new();

    [NotMapped] public decimal Balance => Math.Max(0, GrandTotal - PaidAmount);
    [NotMapped] public string PartyName => ExpenseType switch
    {
        Entities.ExpenseType.Ingredient => Supplier?.SupplierName ?? "",
        Entities.ExpenseType.Tip => Employee?.FullName ?? "",
        _ => ExpenseCategory?.ExpenseCategoryName ?? ""
    };
}

[Table("restaurant_expense_item", Schema = "expense")]
public class RestaurantExpenseItem
{
    [Key]
    public int RestaurantExpenseItemId { get; set; }
    public int RestaurantExpenseId { get; set; }
    public RestaurantExpense? RestaurantExpense { get; set; }
    public int? IngredientId { get; set; }
    public string IngredientName { get; set; } = string.Empty;
    public string? UnitName { get; set; }
    [Column(TypeName = "numeric(12,3)")] public decimal Quantity { get; set; }
    [Column(TypeName = "numeric(12,2)")] public decimal CostPerUnit { get; set; }
    [Column(TypeName = "numeric(12,2)")] public decimal ReorderLevel { get; set; }
    [Column(TypeName = "numeric(12,2)")] public decimal Amount { get; set; }
}

[Table("user_permission", Schema = "admin")]
public class UserPermission
{
    [Key]
    public int UserPermissionId { get; set; }
    public int UserId { get; set; }
    public string ModuleKey { get; set; } = string.Empty;
    public bool CanView { get; set; }
    public bool CanAdd { get; set; }
    public bool CanEdit { get; set; }
    public bool CanDelete { get; set; }
}
