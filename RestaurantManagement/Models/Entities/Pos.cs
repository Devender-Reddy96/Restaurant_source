using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RestaurantManagement.Models.Entities;

public static class OrderStatus
{
    public const string Open = "Open", Paid = "Paid", Cancelled = "Cancelled";
}

public static class ItemStatus
{
    public const string New = "New", Preparing = "Preparing", Ready = "Ready", Served = "Served", Cancelled = "Cancelled";
}

[Table("restaurant_setting", Schema = "pos")]
public class RestaurantSetting
{
    [Key]
    public int RestaurantSettingId { get; set; } = 1;

    [Display(Name = "Restaurant Name")]
    [Required(ErrorMessage = "Restaurant Name is required.")]
    [StringLength(150)]
    public string RestaurantName { get; set; } = "My Restaurant";

    [Display(Name = "Owner Name")]
    [StringLength(100)]
    public string? OwnerName { get; set; }

    [Display(Name = "Owner Mobile (for 'pay to mobile number')")]
    [RegularExpression(@"^[6-9]\d{9}$", ErrorMessage = "Enter a valid 10-digit Indian mobile number.")]
    public string? OwnerMobile { get; set; }

    [Display(Name = "Owner UPI ID")]
    [RegularExpression(@"^[A-Za-z0-9.\-_]{2,}@[A-Za-z]{2,}$", ErrorMessage = "Enter a valid UPI ID such as name@okhdfcbank.")]
    [StringLength(100)]
    public string? UpiId { get; set; }

    [Display(Name = "UPI Payee Name")]
    [StringLength(100)]
    public string? UpiPayeeName { get; set; }

    [Display(Name = "Public Base URL (for customer pay links)")]
    [StringLength(200)]
    public string? PublicBaseUrl { get; set; }

    [Display(Name = "Bill Footer")]
    [StringLength(300)]
    public string? BillFooter { get; set; }

    public DateTime UpdatedOn { get; set; } = DateTime.UtcNow;
}

[Table("customer_order", Schema = "pos")]
public class CustomerOrder
{
    [Key]
    public int OrderId { get; set; }
    public string OrderNo { get; set; } = string.Empty;
    public string OrderType { get; set; } = "DineIn";      // DineIn | Parcel
    public int? DiningTableId { get; set; }
    [ValidateNever] public DiningTable? DiningTable { get; set; }
    public int Guests { get; set; } = 1;
    public int? CustomerId { get; set; }
    public string? CustomerName { get; set; }
    public string? CustomerMobile { get; set; }
    public string Status { get; set; } = OrderStatus.Open;

    [Column(TypeName = "numeric(12,2)")] public decimal SubTotal { get; set; }
    [Column(TypeName = "numeric(12,2)")] public decimal TaxAmount { get; set; }
    [Column(TypeName = "numeric(12,2)")] public decimal DiscountAmount { get; set; }
    [Column(TypeName = "numeric(12,2)")] public decimal RoundOff { get; set; }
    [Column(TypeName = "numeric(12,2)")] public decimal GrandTotal { get; set; }
    [Column(TypeName = "numeric(12,2)")] public decimal PaidAmount { get; set; }
    public int? DiscountId { get; set; }
    public string? DiscountCode { get; set; }
    [Column(TypeName = "numeric(6,2)")] public decimal DiscountPercent { get; set; }
    [Column(TypeName = "numeric(12,2)")] public decimal TipAmount { get; set; }
    public int? WaiterEmployeeId { get; set; }
    [ForeignKey(nameof(WaiterEmployeeId)), ValidateNever] public Employee? WaiterEmployee { get; set; }

    public Guid PayToken { get; set; } = Guid.NewGuid();
    public string? CustomerUtr { get; set; }
    public string? Notes { get; set; }
    public string? CreatedBy { get; set; }
    public DateTime CreatedOn { get; set; } = DateTime.UtcNow;
    public DateTime? PaidOn { get; set; }

    public List<OrderItem> Items { get; set; } = new();
    public List<OrderPayment> Payments { get; set; } = new();

    [NotMapped] public decimal DueAmount => Math.Max(0, GrandTotal - PaidAmount);
    /// <summary>Effective tax % on the taxable value (0 when no items).</summary>
    [NotMapped] public decimal TaxPercentEffective => SubTotal == 0 ? 0 : Math.Round(TaxAmount * 100 / SubTotal, 2);
    /// <summary>Discount as % of (sub-total + tax); works for both % and flat discounts.</summary>
    [NotMapped] public decimal DiscountPercentEffective => DiscountPercent > 0 ? DiscountPercent
        : (SubTotal + TaxAmount == 0 ? 0 : Math.Round(DiscountAmount * 100 / (SubTotal + TaxAmount), 2));
    [NotMapped] public string PaymentModeText => string.Join(", ", Payments.Select(p => p.ModeName).Distinct());
}

[Table("order_item", Schema = "pos")]
public class OrderItem
{
    [Key]
    public int OrderItemId { get; set; }
    public int OrderId { get; set; }
    public CustomerOrder? Order { get; set; }
    public int? FoodItemId { get; set; }
    public string ItemName { get; set; } = string.Empty;
    public string? FoodType { get; set; }
    public int Quantity { get; set; } = 1;
    [Column(TypeName = "numeric(12,2)")] public decimal UnitPrice { get; set; }
    /// <summary>Sum of the add-on prices for ONE unit of this item.</summary>
    [Column(TypeName = "numeric(12,2)")] public decimal AddonUnitPrice { get; set; }
    public string? AddonNames { get; set; }
    public List<OrderItemAddon> Addons { get; set; } = new();
    [Column(TypeName = "numeric(12,2)")] public decimal TaxPercent { get; set; }
    public bool TaxInclusive { get; set; }
    [Column(TypeName = "numeric(12,2)")] public decimal LineBase { get; set; }
    [Column(TypeName = "numeric(12,2)")] public decimal TaxAmount { get; set; }
    [Column(TypeName = "numeric(12,2)")] public decimal LineTotal { get; set; }
    public string? Note { get; set; }
    public int? KitchenStationId { get; set; }
    public int RoundNo { get; set; } = 1;
    public string Status { get; set; } = ItemStatus.New;
    public DateTime CreatedOn { get; set; } = DateTime.UtcNow;
    public DateTime? StartedOn { get; set; }
    public DateTime? ReadyOn { get; set; }
    public DateTime? ServedOn { get; set; }
}

[Table("order_payment", Schema = "pos")]
public class OrderPayment
{
    [Key]
    public int OrderPaymentId { get; set; }
    public int OrderId { get; set; }
    public CustomerOrder? Order { get; set; }
    public string ModeName { get; set; } = "Cash";
    [Column(TypeName = "numeric(12,2)")] public decimal Amount { get; set; }
    public string? ReferenceNo { get; set; }
    public string? ReceivedBy { get; set; }
    public DateTime CreatedOn { get; set; } = DateTime.UtcNow;
}

[Table("table_waiting", Schema = "pos")]
public class TableWaiting
{
    [Key]
    public int TableWaitingId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string? Mobile { get; set; }
    public int PartySize { get; set; } = 2;
    public string Status { get; set; } = "Waiting";          // Waiting | Seated | Cancelled
    public int? AssignedTableId { get; set; }
    public DateTime CreatedOn { get; set; } = DateTime.UtcNow;
    public DateTime? SeatedOn { get; set; }
}

[Table("order_item_addon", Schema = "pos")]
public class OrderItemAddon
{
    [Key]
    public int OrderItemAddonId { get; set; }
    public int OrderItemId { get; set; }
    public OrderItem? OrderItem { get; set; }
    public int? AddonId { get; set; }
    public string AddonName { get; set; } = string.Empty;
    [Column(TypeName = "numeric(12,2)")] public decimal Price { get; set; }
}
