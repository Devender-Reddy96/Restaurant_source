# Restaurant Management System (ASP.NET Core MVC, .NET 10)

Built from *Restaurant_Management_System_Blueprint.html* - ASP.NET Core MVC + Entity Framework Core + PostgreSQL.
Opens in **Visual Studio 2026** (workload: *ASP.NET and web development*, .NET 10 SDK).

## Run it
1. Install PostgreSQL. In pgAdmin create a database named `RestaurantDB`.
2. Run **RestaurantDB.sql** (delivered separately) in the Query Tool of that database.
3. Open `RestaurantManagement.sln`, edit `RestaurantManagement/appsettings.json` -> `DefaultConnection` (host, user, password).
4. Press **F5**. Sign in with `admin` / `Admin@123`, then change the password under *Users & Login*.

## What is included (this release = all masters + login + dashboard)
- **Branches** (`admin.branch_master`)
- **Floors & Areas** (`orders.floor_master`)
- **Tables** (`orders.table_master`)
- **Kitchen Stations** (`orders.kitchen_station`)
- **Food Categories** (`menu.category_master`)
- **Taxes** (`billing.tax_master`)
- **Food Items** (`menu.food_item_master`)
- **Add-ons** (`menu.addon_master`)
- **Designations** (`hr.designation_master`)
- **Shifts** (`hr.shift_master`)
- **Staff / Employees** (`hr.employee_master`)
- **Customers** (`crm.customer_master`)
- **Units of Measure** (`inventory.unit_master`)
- **Ingredients** (`inventory.ingredient_master`)
- **Suppliers** (`purchase.supplier_master`)
- **Discounts & Coupons** (`billing.discount_master`)
- **Payment Modes** (`payments.payment_mode_master`)
- **Expense Categories** (`expense.expense_category_master`)
- **Users & Login** (`admin.user_master`) - Admin only, PBKDF2 password hashing
- Dashboard with counts, table status, items per category, quick-add buttons (Menu Item / Table / Staff)

Every master has: list with live search, add, edit, delete (with in-use protection), active/inactive switch, validation.
Roles: **Admin** = everything, **Manager** = all masters, other roles are ready for the POS screens.

## Database is ready for the next phase
The SQL script already contains orders, order items, kitchen orders, invoices, payments, refunds, recipes, stock,
purchase orders / invoices, supplier payments, attendance, expense vouchers, feedback, audit log and 3 reporting views
(`reports.vw_daily_sales`, `vw_item_wise_sales`, `vw_stock_status`) - the POS, kitchen, billing and report screens can be added on top without changing the schema.

## Project layout
```
RestaurantManagement/
  Controllers/   one controller per master + Account, Home, Users
  Models/        Entities (one class per table), ViewModels
  Data/          AppDbContext (maps PropertyName -> snake_case column)
  Services/      PasswordHasher
  Views/         Index + Form per master, shared layout and sidebar
  wwwroot/       css, js, uploads (food photos)
```

## Notes
- If NuGet cannot find Npgsql 10.x, change the package version in the .csproj to the latest available.
- GST rates in the Tax master are samples - confirm with your accountant.
- Food photos are saved to `wwwroot/uploads`.

---
## Phase 2: Orders, Kitchen, Waiter, Billing, UPI (added)

### One-time database steps (pgAdmin, database `RestaurantDB`)
1. `Database/01_RestaurantOps_Schema.sql` - creates schema `pos` (orders, order items, payments, table queue, settings).
2. `Database/02_MenuSeed_SouthIndia_India.sql` - 430 menu items in 18 categories (re-runnable).
3. Optional images: run `Tools/Download-MenuImages.ps1`, then `Database/03_MenuImagePaths.sql`.

### New screens (sidebar > Operations)
- **Tables & Orders** - floor-wise table board, **table waiting queue** (assign a table, then take the order), running parcel orders.
- **Order screen** - menu with photos, veg / non-veg filter, search, notes, customer name + mobile; add more rounds to a running table.
- **New Parcel Order** - same screen, **no table needed**.
- **Order Queue** - open orders in sequence with kitchen status per order.
- **Kitchen Display** - FIFO order tickets, items-queue summary (e.g. Masala Dosa x7), Cook / Ready / All ready, station filter, auto refresh, beep on new dishes.
- **Waiter / Bearer** - shows food marked Ready; beep + browser notification; Served / Handed over.
- **Billing & Payments** - bill, discount, UPI QR, WhatsApp / SMS / copy pay link to the customer, record Cash / UPI / Card, print receipt.
- **Restaurant & UPI Settings** - owner UPI ID, payee name, owner mobile, public URL, bill footer.

The customer pay link opens `/Pay/{token}` (no login): pay with any UPI app, GPay / PhonePe / Paytm buttons, QR, and a box to submit the UPI reference number, which the cashier then sees on the bill.

### Things to know
- Payments are confirmed **manually** by the cashier after checking the UPI app / SMS. Automatic confirmation needs a payment gateway (Razorpay, Cashfree, PhonePe PG etc.) and is not included.
- Pay links must be reachable from the customer's phone. Set **Public Base URL** in settings once hosted (localhost does not work on phones).
- Click **Enable alerts** once on the Kitchen / Waiter screen (browsers block sound until a click).
- Menu prices are samples. Tax and Kitchen Station are blank on seeded items; set them under Food Items.

---
## Phase 3 (this update)

### Database (pgAdmin, database `RestaurantDB`)
- **Existing database:** run `Database/04_Phase3_Update.sql` once (safe to run again).
- **New / empty database:** run only `Database/RestaurantDB_Full_Latest.sql` (base + phase 2 + phase 3 in one file).

### What is new
1. **Add-ons on orders** - in the order screen every cart line has an *Add-ons* button. Add-on prices are added to the item rate
   (GST applied the same way), shown on the KOT, waiter screen, bill and receipt. If `menu.food_addon_mapping` has rows for a dish,
   only those add-ons are offered; otherwise every active add-on.
2. **Billing grid** - Billing & Payments now lists every bill with payment mode(s), sub-total, tax %, tax, coupon, discount %, discount,
   round off, total, paid, tip and waiter. Filters: dates, status, payment mode, type, discount/coupon/tip, search; totals row; CSV export.
3. **Restaurant Expenses** (Finance > Restaurant Expenses) - one document screen with three types:
   - *Ingredients*: pick a supplier, add many ingredients (or "List all ingredients"); reorder level and cost per unit come from the
     master and can be edited (optionally saved back to the master). Bill with tax %, discount %, paid amount and balance.
   - *Expense*: expense category + amount, tax %, discount %, paid amount.
   - *Tips*: pick the waiter + amount.
   All are restaurant expenses (never profit). View / print / edit / delete, grid with filters and totals.
4. **Profit & Loss dashboard** (Finance > Profit & Loss) - Today / Yesterday / Last 7 / 30 days / This month / Last month / any From-To.
   Net profit vs previous period, today vs yesterday, KPI tiles with % change, charts (switch Bars / Lines / Doughnut / Pie),
   day-wise P&L grid (filter profit/loss days, sort, CSV), expense documents grid, waiter-wise tips, supplier purchases.
   Income = sales without GST + tips received. Expenses = ingredients + other expenses + tips paid.
5. **Permissions** (Administration > User Permissions, Administrator only) - per user, per screen: View / Add / Edit / Delete.
   New users get their role's defaults; "Reset to role defaults" is available. The Administrator always has full access.
6. **Mobile** - pages, grids, filters, order screen (2-column menu + floating "View order" bar), bills and charts fit phones.
7. **Menu images** (Menu > Menu Images) - the SQL sets an image source and path for every menu item; press
   **Download all missing** and the server downloads each photo into `wwwroot/uploads/menu`. Change the source title and press
   the refresh button on a row to get a different photo. The server needs internet access to wikipedia.org / wikimedia.org.
8. **Coupons** - on the bill, enter a code from Discounts & Coupons. It is accepted only between Valid From and Valid To,
   when active, and when the bill meets the minimum amount. Manual discount can be % or Rs.
9. **Extra payment = tip** - if the customer pays more than the due amount, the extra is saved as a tip for the table bearer
   (picked on the order screen or on the bill) and recorded as a Tip expense.

---
## Phase 4: offline assets, new design, dark mode, mobile

- **Fully offline UI.** Bootstrap, Bootstrap Icons, jQuery, jQuery Validate, Chart.js and the QR library are all loaded from `wwwroot/css` and `wwwroot/js`. No page links to a CDN any more.
- **One-time step:** the icon *font files* were not in the project. Run `Tools/Download-IconFonts.ps1` (or copy `bootstrap-icons.woff2` and `.woff` into `wwwroot/css/fonts/`) so icons show without internet.
- **Collapsible sidebar:** the button at the top-left collapses the menu to icons (desktop, remembered) or slides it in (mobile). Hover an icon to see its name.
- **Light / Dark / Same as device:** sun-moon button in the top bar, remembered per browser. Login and customer pay pages follow it too.
- **Mobile:** bottom quick-bar (Home, Tables, Kitchen, Waiter, Billing, More); order screen has a bottom "View order" bar that opens the order as a sheet.
- **Scrolling fixed:** on the order screen the menu and the order panel scroll separately, so *Send to Kitchen* is always visible. On the bill page the payment column stays in view on desktop and a "Pay now" bar sticks to the bottom on phones.

## Icons not showing (squares)?
The icons use the Bootstrap Icons font. `wwwroot/css/fonts/bootstrap-icons.woff2/.woff` are fetched on build
(or loaded from the jsDelivr CDN as a fallback). If you work fully offline, copy those two files from
https://github.com/twbs/icons/tree/v1.11.3/font/fonts into `wwwroot/css/fonts/` and hard-refresh (Ctrl+F5).
