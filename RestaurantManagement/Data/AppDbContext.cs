using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.Models.Entities;

namespace RestaurantManagement.Data;

/// <summary>Database-first context: tables are created by RestaurantDB.sql (PostgreSQL).</summary>
public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<AppUser> Users => Set<AppUser>();
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<Branch> Branches => Set<Branch>();
    public DbSet<Floor> Floors => Set<Floor>();
    public DbSet<DiningTable> DiningTables => Set<DiningTable>();
    public DbSet<KitchenStation> KitchenStations => Set<KitchenStation>();
    public DbSet<Category> Categories => Set<Category>();
    public DbSet<Tax> Taxes => Set<Tax>();
    public DbSet<FoodItem> FoodItems => Set<FoodItem>();
    public DbSet<Addon> Addons => Set<Addon>();
    public DbSet<Designation> Designations => Set<Designation>();
    public DbSet<Shift> Shifts => Set<Shift>();
    public DbSet<Employee> Employees => Set<Employee>();
    public DbSet<Customer> Customers => Set<Customer>();
    public DbSet<Unit> Units => Set<Unit>();
    public DbSet<Ingredient> Ingredients => Set<Ingredient>();
    public DbSet<Supplier> Suppliers => Set<Supplier>();
    public DbSet<Discount> Discounts => Set<Discount>();
    public DbSet<PaymentMode> PaymentModes => Set<PaymentMode>();
    public DbSet<ExpenseCategory> ExpenseCategories => Set<ExpenseCategory>();
    public DbSet<RestaurantSetting> RestaurantSettings => Set<RestaurantSetting>();
    public DbSet<CustomerOrder> CustomerOrders => Set<CustomerOrder>();
    public DbSet<OrderItem> OrderItems => Set<OrderItem>();
    public DbSet<OrderPayment> OrderPayments => Set<OrderPayment>();
    public DbSet<TableWaiting> TableWaitings => Set<TableWaiting>();
    public DbSet<OrderItemAddon> OrderItemAddons => Set<OrderItemAddon>();
    public DbSet<RestaurantExpense> RestaurantExpenses => Set<RestaurantExpense>();
    public DbSet<RestaurantExpenseItem> RestaurantExpenseItems => Set<RestaurantExpenseItem>();
    public DbSet<UserPermission> UserPermissions => Set<UserPermission>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Property "FoodItemId" -> column "food_item_id" (matches the SQL script).
        foreach (var entity in modelBuilder.Model.GetEntityTypes())
        {
            foreach (var property in entity.GetProperties())
            {
                property.SetColumnName(ToSnakeCase(property.Name));
            }
        }
    }

    private static string ToSnakeCase(string name) =>
        Regex.Replace(name, "([a-z0-9])([A-Z])", "$1_$2").ToLowerInvariant();
}
