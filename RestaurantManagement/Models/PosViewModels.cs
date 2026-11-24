using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Models;

public class PlaceOrderLine
{
    public int FoodItemId { get; set; }
    public int Quantity { get; set; } = 1;
    public string? Note { get; set; }
    public List<int> AddonIds { get; set; } = new();
}

public class PlaceOrderRequest
{
    public int? OrderId { get; set; }
    public string OrderType { get; set; } = "DineIn";
    public int? DiningTableId { get; set; }
    public int Guests { get; set; } = 1;
    public string? CustomerName { get; set; }
    public string? CustomerMobile { get; set; }
    public string? Notes { get; set; }
    public int? WaitingId { get; set; }
    public int? WaiterEmployeeId { get; set; }
    public List<PlaceOrderLine> Lines { get; set; } = new();
}

public class MenuItemDto
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public string Category { get; set; } = "";
    public string FoodType { get; set; } = "Veg";
    public decimal Price { get; set; }
    public decimal TaxPercent { get; set; }
    public bool TaxInclusive { get; set; }
    public string? Image { get; set; }
    public int? PrepMinutes { get; set; }
    /// <summary>Add-ons allowed for this dish. Empty = every active add-on.</summary>
    public List<int> AddonIds { get; set; } = new();
}

public class AddonDto
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public decimal Price { get; set; }
}

public class IdName
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
}

public class TableCard
{
    public DiningTable Table { get; set; } = null!;
    public CustomerOrder? Order { get; set; }
}

public class FloorGroup
{
    public string FloorName { get; set; } = "";
    public List<TableCard> Tables { get; set; } = new();
}

public class PosHomeViewModel
{
    public List<FloorGroup> Floors { get; set; } = new();
    public List<TableWaiting> Waiting { get; set; } = new();
    public List<CustomerOrder> Parcels { get; set; } = new();
    public List<DiningTable> FreeTables { get; set; } = new();
}

public class OrderScreenViewModel
{
    public CustomerOrder? Order { get; set; }
    public string OrderType { get; set; } = "DineIn";
    public DiningTable? Table { get; set; }
    public int Guests { get; set; } = 2;
    public string? CustomerName { get; set; }
    public string? CustomerMobile { get; set; }
    public int? WaitingId { get; set; }
    public List<MenuItemDto> Menu { get; set; } = new();
    public List<string> Categories { get; set; } = new();
    public List<AddonDto> Addons { get; set; } = new();
    public List<IdName> Waiters { get; set; } = new();
    public int? WaiterEmployeeId { get; set; }
}

public class BillViewModel
{
    public CustomerOrder Order { get; set; } = null!;
    public RestaurantSetting Setting { get; set; } = null!;
    public List<string> PaymentModes { get; set; } = new();
    public List<IdName> Waiters { get; set; } = new();
    public List<Discount> Coupons { get; set; } = new();
    public string UpiLink { get; set; } = "";
    public string PayPageUrl { get; set; } = "";
    public string WhatsAppUrl { get; set; } = "";
    public string SmsUrl { get; set; } = "";
}

public class PayPageViewModel
{
    public CustomerOrder Order { get; set; } = null!;
    public RestaurantSetting Setting { get; set; } = null!;
    public string UpiLink { get; set; } = "";
    public string GPayLink { get; set; } = "";
    public string PhonePeLink { get; set; } = "";
    public string PaytmLink { get; set; } = "";
}

public class PendingDish
{
    public string Name { get; set; } = "";
    public int Quantity { get; set; }
}

public class KitchenBoardViewModel
{
    public List<CustomerOrder> Orders { get; set; } = new();
    public List<PendingDish> Pending { get; set; } = new();
    public int? StationId { get; set; }
}

public class ReadyBoardViewModel
{
    public List<CustomerOrder> Orders { get; set; } = new();
}

public class ExpenseLineRequest
{
    public int IngredientId { get; set; }
    public decimal Quantity { get; set; }
    public decimal CostPerUnit { get; set; }
    public decimal ReorderLevel { get; set; }
}

public class ExpenseSaveRequest
{
    public int? Id { get; set; }
    public string ExpenseType { get; set; } = "Ingredient";
    public DateOnly ExpenseDate { get; set; }
    public int? SupplierId { get; set; }
    public int? ExpenseCategoryId { get; set; }
    public int? EmployeeId { get; set; }
    public string? BillNo { get; set; }
    public string? Description { get; set; }
    public decimal Amount { get; set; }
    public decimal TaxPercent { get; set; }
    public decimal DiscountPercent { get; set; }
    public decimal PaidAmount { get; set; }
    public string? PaymentMode { get; set; }
    public string? ReferenceNo { get; set; }
    public bool UpdateMaster { get; set; } = true;
    public List<ExpenseLineRequest> Items { get; set; } = new();
}
