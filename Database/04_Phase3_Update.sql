/* =====================================================================
   RESTAURANT MANAGEMENT - PHASE 3 UPDATE (PostgreSQL)
   Run AFTER RestaurantDB.sql and RestaurantDB_Phase2_Update.sql
   in database RestaurantDB. Safe to run more than once.

   Adds
     1. Add-ons on order items (pos.order_item_addon)
     2. Bill details: coupon / discount %, tip, waiter on every order
     3. Restaurant expense documents: Ingredient bills, Expenses, Tips
     4. Profit & loss view (reports.vw_daily_profit)
     5. User permissions (admin.user_permission) + defaults for existing users
     7. Menu image source + image path for every menu item
   ===================================================================== */
BEGIN;

-- 1. ADD-ONS ON ORDER ITEMS ---------------------------------------------
ALTER TABLE pos.order_item ADD COLUMN IF NOT EXISTS addon_names      varchar(300);
ALTER TABLE pos.order_item ADD COLUMN IF NOT EXISTS addon_unit_price numeric(12,2) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS pos.order_item_addon (
    order_item_addon_id serial PRIMARY KEY,
    order_item_id       int NOT NULL REFERENCES pos.order_item(order_item_id) ON DELETE CASCADE,
    addon_id            int REFERENCES menu.addon_master(addon_id),
    addon_name          varchar(100) NOT NULL,
    price               numeric(12,2) NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS ix_order_item_addon_item ON pos.order_item_addon(order_item_id);

-- 2. BILL: COUPON, DISCOUNT %, TIP, WAITER -------------------------------
ALTER TABLE pos.customer_order ADD COLUMN IF NOT EXISTS discount_id        int REFERENCES billing.discount_master(discount_id);
ALTER TABLE pos.customer_order ADD COLUMN IF NOT EXISTS discount_code      varchar(30);
ALTER TABLE pos.customer_order ADD COLUMN IF NOT EXISTS discount_percent   numeric(6,2) NOT NULL DEFAULT 0;
ALTER TABLE pos.customer_order ADD COLUMN IF NOT EXISTS tip_amount         numeric(12,2) NOT NULL DEFAULT 0;
ALTER TABLE pos.customer_order ADD COLUMN IF NOT EXISTS waiter_employee_id int REFERENCES hr.employee_master(employee_id);
CREATE INDEX IF NOT EXISTS ix_customer_order_paid_on ON pos.customer_order(paid_on);
CREATE INDEX IF NOT EXISTS ix_order_payment_order    ON pos.order_payment(order_id);

-- 3. RESTAURANT EXPENSE DOCUMENTS ---------------------------------------
--    expense_type: Ingredient (supplier bill) | Expense (category) | Tip (waiter)
CREATE SEQUENCE IF NOT EXISTS expense.restaurant_expense_no_seq START 1001;

CREATE TABLE IF NOT EXISTS expense.restaurant_expense (
    restaurant_expense_id serial PRIMARY KEY,
    doc_no               varchar(30) NOT NULL UNIQUE,
    expense_type         varchar(20) NOT NULL,
    expense_date         date NOT NULL DEFAULT CURRENT_DATE,
    supplier_id          int REFERENCES purchase.supplier_master(supplier_id),
    expense_category_id  int REFERENCES expense.expense_category_master(expense_category_id),
    employee_id          int REFERENCES hr.employee_master(employee_id),
    order_id             int REFERENCES pos.customer_order(order_id) ON DELETE SET NULL,
    bill_no              varchar(50),
    description          varchar(300),
    sub_total            numeric(12,2) NOT NULL DEFAULT 0,
    tax_percent          numeric(6,2)  NOT NULL DEFAULT 0,
    tax_amount           numeric(12,2) NOT NULL DEFAULT 0,
    discount_percent     numeric(6,2)  NOT NULL DEFAULT 0,
    discount_amount      numeric(12,2) NOT NULL DEFAULT 0,
    grand_total          numeric(12,2) NOT NULL DEFAULT 0,
    paid_amount          numeric(12,2) NOT NULL DEFAULT 0,
    payment_mode         varchar(50),
    reference_no         varchar(60),
    created_by           varchar(100),
    created_on           timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_restaurant_expense_type CHECK (expense_type IN ('Ingredient','Expense','Tip'))
);
CREATE INDEX IF NOT EXISTS ix_restaurant_expense_date ON expense.restaurant_expense(expense_date);
CREATE INDEX IF NOT EXISTS ix_restaurant_expense_type ON expense.restaurant_expense(expense_type);

CREATE TABLE IF NOT EXISTS expense.restaurant_expense_item (
    restaurant_expense_item_id serial PRIMARY KEY,
    restaurant_expense_id      int NOT NULL REFERENCES expense.restaurant_expense(restaurant_expense_id) ON DELETE CASCADE,
    ingredient_id              int REFERENCES inventory.ingredient_master(ingredient_id),
    ingredient_name            varchar(100) NOT NULL,
    unit_name                  varchar(20),
    quantity                   numeric(12,3) NOT NULL DEFAULT 0,
    cost_per_unit              numeric(12,2) NOT NULL DEFAULT 0,
    reorder_level              numeric(12,2) NOT NULL DEFAULT 0,
    amount                     numeric(12,2) NOT NULL DEFAULT 0
);

-- 4. PROFIT & LOSS VIEW (IST dates) -------------------------------------
CREATE OR REPLACE VIEW reports.vw_daily_profit AS
WITH s AS (
    SELECT (paid_on AT TIME ZONE 'Asia/Kolkata')::date AS d,
           COUNT(*) AS orders, SUM(grand_total - tax_amount) AS net_sales, SUM(tax_amount) AS tax,
           SUM(discount_amount) AS discount, SUM(tip_amount) AS tips_received
    FROM pos.customer_order WHERE status = 'Paid' GROUP BY 1),
e AS (
    SELECT expense_date AS d,
           SUM(CASE WHEN expense_type = 'Ingredient' THEN grand_total ELSE 0 END) AS ingredient_cost,
           SUM(CASE WHEN expense_type = 'Expense'    THEN grand_total ELSE 0 END) AS other_expense,
           SUM(CASE WHEN expense_type = 'Tip'        THEN grand_total ELSE 0 END) AS tips_paid
    FROM expense.restaurant_expense GROUP BY 1)
SELECT COALESCE(s.d, e.d) AS business_date,
       COALESCE(s.orders, 0) AS orders,
       COALESCE(s.net_sales, 0) AS net_sales,
       COALESCE(s.tax, 0) AS tax_collected,
       COALESCE(s.discount, 0) AS discount_given,
       COALESCE(s.tips_received, 0) AS tips_received,
       COALESCE(e.ingredient_cost, 0) AS ingredient_cost,
       COALESCE(e.other_expense, 0) AS other_expense,
       COALESCE(e.tips_paid, 0) AS tips_paid,
       COALESCE(s.net_sales, 0) + COALESCE(s.tips_received, 0)
         - COALESCE(e.ingredient_cost, 0) - COALESCE(e.other_expense, 0) - COALESCE(e.tips_paid, 0) AS net_profit
FROM s FULL OUTER JOIN e ON e.d = s.d;

-- 5. USER PERMISSIONS (only Administrator can change them) ---------------
CREATE TABLE IF NOT EXISTS admin.user_permission (
    user_permission_id serial PRIMARY KEY,
    user_id    int NOT NULL REFERENCES admin.user_master(user_id) ON DELETE CASCADE,
    module_key varchar(50) NOT NULL,
    can_view   boolean NOT NULL DEFAULT false,
    can_add    boolean NOT NULL DEFAULT false,
    can_edit   boolean NOT NULL DEFAULT false,
    can_delete boolean NOT NULL DEFAULT false,
    CONSTRAINT uq_user_permission UNIQUE (user_id, module_key)
);

-- Defaults for existing non-admin users (same defaults the app uses for new users)
INSERT INTO admin.user_permission (user_id, module_key, can_view, can_add, can_edit, can_delete)
SELECT u.user_id, m.k, true, true, true, true
FROM admin.user_master u JOIN admin.role_master r ON r.role_id = u.role_id
CROSS JOIN (VALUES ('Pos'),('Kitchen'),('Waiter'),('Billing'),('Expenses'),('Reports'),('Categories'),('FoodItems'),
                   ('Addons'),('MenuImages'),('Floors'),('DiningTables'),('KitchenStations'),('Employees'),('Designations'),
                   ('Shifts'),('Customers'),('Suppliers'),('Units'),('Ingredients'),('Taxes'),('Discounts'),
                   ('PaymentModes'),('RestaurantSettings'),('ExpenseCategories')) AS m(k)
WHERE r.role_name = 'Manager'
ON CONFLICT (user_id, module_key) DO NOTHING;

INSERT INTO admin.user_permission (user_id, module_key, can_view, can_add, can_edit, can_delete)
SELECT u.user_id, m.k, m.v, m.a, m.e, m.d
FROM admin.user_master u JOIN admin.role_master r ON r.role_id = u.role_id
JOIN (VALUES
    ('Cashier','Pos',true,true,true,false), ('Cashier','Billing',true,true,true,false),
    ('Cashier','Expenses',true,true,false,false), ('Cashier','Customers',true,true,true,false),
    ('Waiter','Pos',true,true,true,false), ('Waiter','Waiter',true,true,true,false),
    ('Chef','Kitchen',true,true,true,false)
) AS m(role, k, v, a, e, d) ON m.role = r.role_name
ON CONFLICT (user_id, module_key) DO NOTHING;

-- 6. (mobile layout is CSS only - nothing in the database)

ALTER TABLE menu.food_item_master ADD COLUMN IF NOT EXISTS image_source varchar(200);

-- 7. MENU IMAGES: source title (Wikipedia page) + image path for every menu item
--    The app's  Menu > Menu Images > 'Download all missing'  saves each photo to wwwroot/uploads/menu/<file>.jpg
UPDATE menu.food_item_master SET image_source = 'Idli', image_path = '/uploads/menu/Idli.jpg' WHERE item_code = 'SI0001' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Idli', image_path = '/uploads/menu/Idli.jpg' WHERE item_code = 'SI0002' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Idli', image_path = '/uploads/menu/Idli.jpg' WHERE item_code = 'SI0003' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Thatte idli', image_path = '/uploads/menu/Thatte_idli.jpg' WHERE item_code = 'SI0004' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Rava idli', image_path = '/uploads/menu/Rava_idli.jpg' WHERE item_code = 'SI0005' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kanchipuram idli', image_path = '/uploads/menu/Kanchipuram_idli.jpg' WHERE item_code = 'SI0006' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Medu vada', image_path = '/uploads/menu/Medu_vada.jpg' WHERE item_code = 'SI0007' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Medu vada', image_path = '/uploads/menu/Medu_vada.jpg' WHERE item_code = 'SI0008' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Medu vada', image_path = '/uploads/menu/Medu_vada.jpg' WHERE item_code = 'SI0009' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dahi vada', image_path = '/uploads/menu/Dahi_vada.jpg' WHERE item_code = 'SI0010' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Masala vada', image_path = '/uploads/menu/Masala_vada.jpg' WHERE item_code = 'SI0011' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Idli', image_path = '/uploads/menu/Idli.jpg' WHERE item_code = 'SI0012' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Upma', image_path = '/uploads/menu/Upma.jpg' WHERE item_code = 'SI0013' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kesari bath', image_path = '/uploads/menu/Kesari_bath.jpg' WHERE item_code = 'SI0014' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Upma', image_path = '/uploads/menu/Upma.jpg' WHERE item_code = 'SI0015' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pongal (dish)', image_path = '/uploads/menu/Pongal_dish.jpg' WHERE item_code = 'SI0016' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pongal (dish)', image_path = '/uploads/menu/Pongal_dish.jpg' WHERE item_code = 'SI0017' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Poori', image_path = '/uploads/menu/Poori.jpg' WHERE item_code = 'SI0018' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chapati', image_path = '/uploads/menu/Chapati.jpg' WHERE item_code = 'SI0019' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Uttapam', image_path = '/uploads/menu/Uttapam.jpg' WHERE item_code = 'SI0020' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Uttapam', image_path = '/uploads/menu/Uttapam.jpg' WHERE item_code = 'SI0021' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Uttapam', image_path = '/uploads/menu/Uttapam.jpg' WHERE item_code = 'SI0022' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Uttapam', image_path = '/uploads/menu/Uttapam.jpg' WHERE item_code = 'SI0023' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Appam', image_path = '/uploads/menu/Appam.jpg' WHERE item_code = 'SI0024' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Idiyappam', image_path = '/uploads/menu/Idiyappam.jpg' WHERE item_code = 'SI0025' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Puttu', image_path = '/uploads/menu/Puttu.jpg' WHERE item_code = 'SI0026' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pesarattu', image_path = '/uploads/menu/Pesarattu.jpg' WHERE item_code = 'SI0027' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Akki roti', image_path = '/uploads/menu/Akki_roti.jpg' WHERE item_code = 'SI0028' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Ragi mudde', image_path = '/uploads/menu/Ragi_mudde.jpg' WHERE item_code = 'SI0029' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Bonda', image_path = '/uploads/menu/Bonda.jpg' WHERE item_code = 'SI0030' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Mirchi bajji', image_path = '/uploads/menu/Mirchi_bajji.jpg' WHERE item_code = 'SI0031' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Paniyaram', image_path = '/uploads/menu/Paniyaram.jpg' WHERE item_code = 'SI0032' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Bisi bele bath', image_path = '/uploads/menu/Bisi_bele_bath.jpg' WHERE item_code = 'SI0033' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Sabudana khichdi', image_path = '/uploads/menu/Sabudana_khichdi.jpg' WHERE item_code = 'SI0034' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dosa', image_path = '/uploads/menu/Dosa.jpg' WHERE item_code = 'SI0035' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Masala dosa', image_path = '/uploads/menu/Masala_dosa.jpg' WHERE item_code = 'SI0036' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dosa', image_path = '/uploads/menu/Dosa.jpg' WHERE item_code = 'SI0037' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Mysore masala dosa', image_path = '/uploads/menu/Mysore_masala_dosa.jpg' WHERE item_code = 'SI0038' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Rava dosa', image_path = '/uploads/menu/Rava_dosa.jpg' WHERE item_code = 'SI0039' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Rava dosa', image_path = '/uploads/menu/Rava_dosa.jpg' WHERE item_code = 'SI0040' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Rava dosa', image_path = '/uploads/menu/Rava_dosa.jpg' WHERE item_code = 'SI0041' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Set dosa', image_path = '/uploads/menu/Set_dosa.jpg' WHERE item_code = 'SI0042' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Neer dosa', image_path = '/uploads/menu/Neer_dosa.jpg' WHERE item_code = 'SI0043' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Benne dose', image_path = '/uploads/menu/Benne_dose.jpg' WHERE item_code = 'SI0044' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Paper dosa', image_path = '/uploads/menu/Paper_dosa.jpg' WHERE item_code = 'SI0045' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dosa', image_path = '/uploads/menu/Dosa.jpg' WHERE item_code = 'SI0046' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dosa', image_path = '/uploads/menu/Dosa.jpg' WHERE item_code = 'SI0047' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dosa', image_path = '/uploads/menu/Dosa.jpg' WHERE item_code = 'SI0048' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dosa', image_path = '/uploads/menu/Dosa.jpg' WHERE item_code = 'SI0049' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dosa', image_path = '/uploads/menu/Dosa.jpg' WHERE item_code = 'SI0050' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Adai', image_path = '/uploads/menu/Adai.jpg' WHERE item_code = 'SI0051' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Adai', image_path = '/uploads/menu/Adai.jpg' WHERE item_code = 'SI0052' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Ragi', image_path = '/uploads/menu/Ragi.jpg' WHERE item_code = 'SI0053' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dosa', image_path = '/uploads/menu/Dosa.jpg' WHERE item_code = 'SI0054' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kal dosa', image_path = '/uploads/menu/Kal_dosa.jpg' WHERE item_code = 'SI0055' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dosa', image_path = '/uploads/menu/Dosa.jpg' WHERE item_code = 'SI0056' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dosa', image_path = '/uploads/menu/Dosa.jpg' WHERE item_code = 'SI0057' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dosa', image_path = '/uploads/menu/Dosa.jpg' WHERE item_code = 'SI0058' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dosa', image_path = '/uploads/menu/Dosa.jpg' WHERE item_code = 'SI0059' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Curd rice', image_path = '/uploads/menu/Curd_rice.jpg' WHERE item_code = 'SI0060' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Lemon rice', image_path = '/uploads/menu/Lemon_rice.jpg' WHERE item_code = 'SI0061' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pulihora', image_path = '/uploads/menu/Pulihora.jpg' WHERE item_code = 'SI0062' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Tomato rice', image_path = '/uploads/menu/Tomato_rice.jpg' WHERE item_code = 'SI0063' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Coconut rice', image_path = '/uploads/menu/Coconut_rice.jpg' WHERE item_code = 'SI0064' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Vangibath', image_path = '/uploads/menu/Vangibath.jpg' WHERE item_code = 'SI0065' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Sambar rice', image_path = '/uploads/menu/Sambar_rice.jpg' WHERE item_code = 'SI0066' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Rasam', image_path = '/uploads/menu/Rasam.jpg' WHERE item_code = 'SI0067' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Ghee rice', image_path = '/uploads/menu/Ghee_rice.jpg' WHERE item_code = 'SI0068' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Jeera rice', image_path = '/uploads/menu/Jeera_rice.jpg' WHERE item_code = 'SI0069' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Steamed rice', image_path = '/uploads/menu/Steamed_rice.jpg' WHERE item_code = 'SI0070' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Matta rice', image_path = '/uploads/menu/Matta_rice.jpg' WHERE item_code = 'SI0071' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Gongura', image_path = '/uploads/menu/Gongura.jpg' WHERE item_code = 'SI0072' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Mango rice', image_path = '/uploads/menu/Mango_rice.jpg' WHERE item_code = 'SI0073' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Bagara rice', image_path = '/uploads/menu/Bagara_rice.jpg' WHERE item_code = 'SI0075' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kuska', image_path = '/uploads/menu/Kuska.jpg' WHERE item_code = 'SI0076' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Fried rice', image_path = '/uploads/menu/Fried_rice.jpg' WHERE item_code = 'SI0077' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Meal', image_path = '/uploads/menu/Meal.jpg' WHERE item_code = 'SI0078' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Meal', image_path = '/uploads/menu/Meal.jpg' WHERE item_code = 'SI0079' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Andhra cuisine', image_path = '/uploads/menu/Andhra_cuisine.jpg' WHERE item_code = 'SI0080' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Sadhya', image_path = '/uploads/menu/Sadhya.jpg' WHERE item_code = 'SI0081' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Karnataka', image_path = '/uploads/menu/Karnataka.jpg' WHERE item_code = 'SI0082' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chettinad cuisine', image_path = '/uploads/menu/Chettinad_cuisine.jpg' WHERE item_code = 'SI0083' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Meal', image_path = '/uploads/menu/Meal.jpg' WHERE item_code = 'SI0084' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Udupi cuisine', image_path = '/uploads/menu/Udupi_cuisine.jpg' WHERE item_code = 'SI0085' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Meal', image_path = '/uploads/menu/Meal.jpg' WHERE item_code = 'SI0086' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Meal', image_path = '/uploads/menu/Meal.jpg' WHERE item_code = 'SI0087' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Meal', image_path = '/uploads/menu/Meal.jpg' WHERE item_code = 'SI0088' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Meal', image_path = '/uploads/menu/Meal.jpg' WHERE item_code = 'SI0089' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Curd rice', image_path = '/uploads/menu/Curd_rice.jpg' WHERE item_code = 'SI0090' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Thali', image_path = '/uploads/menu/Thali.jpg' WHERE item_code = 'SI0092' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Thali', image_path = '/uploads/menu/Thali.jpg' WHERE item_code = 'SI0093' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Thali', image_path = '/uploads/menu/Thali.jpg' WHERE item_code = 'SI0094' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Thali', image_path = '/uploads/menu/Thali.jpg' WHERE item_code = 'SI0095' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Hyderabadi biryani', image_path = '/uploads/menu/Hyderabadi_biryani.jpg' WHERE item_code = 'SI0096' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Hyderabadi biryani', image_path = '/uploads/menu/Hyderabadi_biryani.jpg' WHERE item_code = 'SI0097' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Hyderabadi biryani', image_path = '/uploads/menu/Hyderabadi_biryani.jpg' WHERE item_code = 'SI0098' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Hyderabadi biryani', image_path = '/uploads/menu/Hyderabadi_biryani.jpg' WHERE item_code = 'SI0099' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Biryani', image_path = '/uploads/menu/Biryani.jpg' WHERE item_code = 'SI0100' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Ambur biryani', image_path = '/uploads/menu/Ambur_biryani.jpg' WHERE item_code = 'SI0101' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dindigul Thalappakatti', image_path = '/uploads/menu/Dindigul_Thalappakatti.jpg' WHERE item_code = 'SI0102' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chettinad cuisine', image_path = '/uploads/menu/Chettinad_cuisine.jpg' WHERE item_code = 'SI0103' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Thalassery biryani', image_path = '/uploads/menu/Thalassery_biryani.jpg' WHERE item_code = 'SI0104' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Biryani', image_path = '/uploads/menu/Biryani.jpg' WHERE item_code = 'SI0105' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Donne biryani', image_path = '/uploads/menu/Donne_biryani.jpg' WHERE item_code = 'SI0106' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Awadhi biryani', image_path = '/uploads/menu/Awadhi_biryani.jpg' WHERE item_code = 'SI0107' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kolkata biryani', image_path = '/uploads/menu/Kolkata_biryani.jpg' WHERE item_code = 'SI0108' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Biryani', image_path = '/uploads/menu/Biryani.jpg' WHERE item_code = 'SI0109' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Biryani', image_path = '/uploads/menu/Biryani.jpg' WHERE item_code = 'SI0110' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Biryani', image_path = '/uploads/menu/Biryani.jpg' WHERE item_code = 'SI0111' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Biryani', image_path = '/uploads/menu/Biryani.jpg' WHERE item_code = 'SI0112' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Biryani', image_path = '/uploads/menu/Biryani.jpg' WHERE item_code = 'SI0113' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pulao', image_path = '/uploads/menu/Pulao.jpg' WHERE item_code = 'SI0114' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pulao', image_path = '/uploads/menu/Pulao.jpg' WHERE item_code = 'SI0115' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pulao', image_path = '/uploads/menu/Pulao.jpg' WHERE item_code = 'SI0116' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Biryani', image_path = '/uploads/menu/Biryani.jpg' WHERE item_code = 'SI0117' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Sambar (dish)', image_path = '/uploads/menu/Sambar_dish.jpg' WHERE item_code = 'SI0118' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Rasam', image_path = '/uploads/menu/Rasam.jpg' WHERE item_code = 'SI0119' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kootu', image_path = '/uploads/menu/Kootu.jpg' WHERE item_code = 'SI0120' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Avial', image_path = '/uploads/menu/Avial.jpg' WHERE item_code = 'SI0121' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Poriyal', image_path = '/uploads/menu/Poriyal.jpg' WHERE item_code = 'SI0122' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Stew', image_path = '/uploads/menu/Stew.jpg' WHERE item_code = 'SI0123' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Korma', image_path = '/uploads/menu/Korma.jpg' WHERE item_code = 'SI0124' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chettinad cuisine', image_path = '/uploads/menu/Chettinad_cuisine.jpg' WHERE item_code = 'SI0125' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pappu', image_path = '/uploads/menu/Pappu.jpg' WHERE item_code = 'SI0127' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pappu', image_path = '/uploads/menu/Pappu.jpg' WHERE item_code = 'SI0128' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dal', image_path = '/uploads/menu/Dal.jpg' WHERE item_code = 'SI0129' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dal', image_path = '/uploads/menu/Dal.jpg' WHERE item_code = 'SI0130' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Parippu', image_path = '/uploads/menu/Parippu.jpg' WHERE item_code = 'SI0131' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pulissery', image_path = '/uploads/menu/Pulissery.jpg' WHERE item_code = 'SI0132' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Mor kuzhambu', image_path = '/uploads/menu/Mor_kuzhambu.jpg' WHERE item_code = 'SI0133' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kuzhambu', image_path = '/uploads/menu/Kuzhambu.jpg' WHERE item_code = 'SI0134' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kuzhambu', image_path = '/uploads/menu/Kuzhambu.jpg' WHERE item_code = 'SI0135' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Mirchi ka salan', image_path = '/uploads/menu/Mirchi_ka_salan.jpg' WHERE item_code = 'SI0136' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Bagara baingan', image_path = '/uploads/menu/Bagara_baingan.jpg' WHERE item_code = 'SI0137' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Paneer tikka masala', image_path = '/uploads/menu/Paneer_tikka_masala.jpg' WHERE item_code = 'SI0138' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Karahi', image_path = '/uploads/menu/Karahi.jpg' WHERE item_code = 'SI0139' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Palak paneer', image_path = '/uploads/menu/Palak_paneer.jpg' WHERE item_code = 'SI0140' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Paneer tikka masala', image_path = '/uploads/menu/Paneer_tikka_masala.jpg' WHERE item_code = 'SI0141' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Malai kofta', image_path = '/uploads/menu/Malai_kofta.jpg' WHERE item_code = 'SI0142' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Mixed vegetable curry', image_path = '/uploads/menu/Mixed_vegetable_curry.jpg' WHERE item_code = 'SI0143' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Aloo gobi', image_path = '/uploads/menu/Aloo_gobi.jpg' WHERE item_code = 'SI0144' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chana masala', image_path = '/uploads/menu/Chana_masala.jpg' WHERE item_code = 'SI0145' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Rajma', image_path = '/uploads/menu/Rajma.jpg' WHERE item_code = 'SI0146' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Baingan bharta', image_path = '/uploads/menu/Baingan_bharta.jpg' WHERE item_code = 'SI0147' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Bhindi masala', image_path = '/uploads/menu/Bhindi_masala.jpg' WHERE item_code = 'SI0148' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Mushroom', image_path = '/uploads/menu/Mushroom.jpg' WHERE item_code = 'SI0149' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dal makhani', image_path = '/uploads/menu/Dal_makhani.jpg' WHERE item_code = 'SI0150' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Methi malai matar', image_path = '/uploads/menu/Methi_malai_matar.jpg' WHERE item_code = 'SI0151' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chettinad chicken', image_path = '/uploads/menu/Chettinad_chicken.jpg' WHERE item_code = 'SI0152' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Andhra cuisine', image_path = '/uploads/menu/Andhra_cuisine.jpg' WHERE item_code = 'SI0153' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kerala cuisine', image_path = '/uploads/menu/Kerala_cuisine.jpg' WHERE item_code = 'SI0154' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kerala cuisine', image_path = '/uploads/menu/Kerala_cuisine.jpg' WHERE item_code = 'SI0155' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chicken ghee roast', image_path = '/uploads/menu/Chicken_ghee_roast.jpg' WHERE item_code = 'SI0156' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kori gassi', image_path = '/uploads/menu/Kori_gassi.jpg' WHERE item_code = 'SI0157' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chicken pepper fry', image_path = '/uploads/menu/Chicken_pepper_fry.jpg' WHERE item_code = 'SI0158' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Andhra cuisine', image_path = '/uploads/menu/Andhra_cuisine.jpg' WHERE item_code = 'SI0159' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chettinad cuisine', image_path = '/uploads/menu/Chettinad_cuisine.jpg' WHERE item_code = 'SI0160' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Butter chicken', image_path = '/uploads/menu/Butter_chicken.jpg' WHERE item_code = 'SI0162' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chicken tikka masala', image_path = '/uploads/menu/Chicken_tikka_masala.jpg' WHERE item_code = 'SI0163' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Karahi', image_path = '/uploads/menu/Karahi.jpg' WHERE item_code = 'SI0164' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Korma', image_path = '/uploads/menu/Korma.jpg' WHERE item_code = 'SI0165' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Mutton chukka', image_path = '/uploads/menu/Mutton_chukka.jpg' WHERE item_code = 'SI0166' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pepper fry', image_path = '/uploads/menu/Pepper_fry.jpg' WHERE item_code = 'SI0167' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Rogan josh', image_path = '/uploads/menu/Rogan_josh.jpg' WHERE item_code = 'SI0168' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Mutton curry', image_path = '/uploads/menu/Mutton_curry.jpg' WHERE item_code = 'SI0169' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Gongura', image_path = '/uploads/menu/Gongura.jpg' WHERE item_code = 'SI0170' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Keema', image_path = '/uploads/menu/Keema.jpg' WHERE item_code = 'SI0171' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Paya', image_path = '/uploads/menu/Paya.jpg' WHERE item_code = 'SI0172' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Haleem', image_path = '/uploads/menu/Haleem.jpg' WHERE item_code = 'SI0173' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Egg curry', image_path = '/uploads/menu/Egg_curry.jpg' WHERE item_code = 'SI0174' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kerala cuisine', image_path = '/uploads/menu/Kerala_cuisine.jpg' WHERE item_code = 'SI0175' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Egg curry', image_path = '/uploads/menu/Egg_curry.jpg' WHERE item_code = 'SI0176' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Beef fry', image_path = '/uploads/menu/Beef_fry.jpg' WHERE item_code = 'SI0177' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kerala cuisine', image_path = '/uploads/menu/Kerala_cuisine.jpg' WHERE item_code = 'SI0178' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Butter chicken', image_path = '/uploads/menu/Butter_chicken.jpg' WHERE item_code = 'SI0179' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Do pyaza', image_path = '/uploads/menu/Do_pyaza.jpg' WHERE item_code = 'SI0180' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Fish curry', image_path = '/uploads/menu/Fish_curry.jpg' WHERE item_code = 'SI0181' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Fish fry', image_path = '/uploads/menu/Fish_fry.jpg' WHERE item_code = 'SI0182' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Karimeen pollichathu', image_path = '/uploads/menu/Karimeen_pollichathu.jpg' WHERE item_code = 'SI0183' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Prawn', image_path = '/uploads/menu/Prawn.jpg' WHERE item_code = 'SI0184' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Prawn', image_path = '/uploads/menu/Prawn.jpg' WHERE item_code = 'SI0185' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chettinad cuisine', image_path = '/uploads/menu/Chettinad_cuisine.jpg' WHERE item_code = 'SI0186' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chepala pulusu', image_path = '/uploads/menu/Chepala_pulusu.jpg' WHERE item_code = 'SI0187' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Mangalorean cuisine', image_path = '/uploads/menu/Mangalorean_cuisine.jpg' WHERE item_code = 'SI0188' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Squid as food', image_path = '/uploads/menu/Squid_as_food.jpg' WHERE item_code = 'SI0189' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Crab', image_path = '/uploads/menu/Crab.jpg' WHERE item_code = 'SI0190' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Anchovy', image_path = '/uploads/menu/Anchovy.jpg' WHERE item_code = 'SI0191' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pomfret', image_path = '/uploads/menu/Pomfret.jpg' WHERE item_code = 'SI0192' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Fish molee', image_path = '/uploads/menu/Fish_molee.jpg' WHERE item_code = 'SI0193' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Prawn', image_path = '/uploads/menu/Prawn.jpg' WHERE item_code = 'SI0194' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Scomberomorus', image_path = '/uploads/menu/Scomberomorus.jpg' WHERE item_code = 'SI0195' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Goan cuisine', image_path = '/uploads/menu/Goan_cuisine.jpg' WHERE item_code = 'SI0196' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Gobi 65', image_path = '/uploads/menu/Gobi_65.jpg' WHERE item_code = 'SI0197' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Paneer', image_path = '/uploads/menu/Paneer.jpg' WHERE item_code = 'SI0198' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Gobi Manchurian', image_path = '/uploads/menu/Gobi_Manchurian.jpg' WHERE item_code = 'SI0199' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Paneer tikka', image_path = '/uploads/menu/Paneer_tikka.jpg' WHERE item_code = 'SI0200' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Hara bhara kabab', image_path = '/uploads/menu/Hara_bhara_kabab.jpg' WHERE item_code = 'SI0201' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Cutlet', image_path = '/uploads/menu/Cutlet.jpg' WHERE item_code = 'SI0202' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Mushroom', image_path = '/uploads/menu/Mushroom.jpg' WHERE item_code = 'SI0203' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Baby corn', image_path = '/uploads/menu/Baby_corn.jpg' WHERE item_code = 'SI0204' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pakora', image_path = '/uploads/menu/Pakora.jpg' WHERE item_code = 'SI0205' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pakora', image_path = '/uploads/menu/Pakora.jpg' WHERE item_code = 'SI0206' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Bajji', image_path = '/uploads/menu/Bajji.jpg' WHERE item_code = 'SI0207' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Aloo 65', image_path = '/uploads/menu/Aloo_65.jpg' WHERE item_code = 'SI0208' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Corn', image_path = '/uploads/menu/Corn.jpg' WHERE item_code = 'SI0209' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Spring roll', image_path = '/uploads/menu/Spring_roll.jpg' WHERE item_code = 'SI0210' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Samosa', image_path = '/uploads/menu/Samosa.jpg' WHERE item_code = 'SI0211' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Seekh kebab', image_path = '/uploads/menu/Seekh_kebab.jpg' WHERE item_code = 'SI0212' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Banana chips', image_path = '/uploads/menu/Banana_chips.jpg' WHERE item_code = 'SI0214' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Murukku', image_path = '/uploads/menu/Murukku.jpg' WHERE item_code = 'SI0215' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chilli paneer', image_path = '/uploads/menu/Chilli_paneer.jpg' WHERE item_code = 'SI0216' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chicken 65', image_path = '/uploads/menu/Chicken_65.jpg' WHERE item_code = 'SI0217' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chicken lollipop', image_path = '/uploads/menu/Chicken_lollipop.jpg' WHERE item_code = 'SI0218' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Apollo fish', image_path = '/uploads/menu/Apollo_fish.jpg' WHERE item_code = 'SI0219' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chilli chicken', image_path = '/uploads/menu/Chilli_chicken.jpg' WHERE item_code = 'SI0220' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chicken Manchurian', image_path = '/uploads/menu/Chicken_Manchurian.jpg' WHERE item_code = 'SI0221' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chicken pepper fry', image_path = '/uploads/menu/Chicken_pepper_fry.jpg' WHERE item_code = 'SI0222' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chicken tikka', image_path = '/uploads/menu/Chicken_tikka.jpg' WHERE item_code = 'SI0223' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Tandoori chicken', image_path = '/uploads/menu/Tandoori_chicken.jpg' WHERE item_code = 'SI0224' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Tandoori chicken', image_path = '/uploads/menu/Tandoori_chicken.jpg' WHERE item_code = 'SI0225' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Seekh kebab', image_path = '/uploads/menu/Seekh_kebab.jpg' WHERE item_code = 'SI0226' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Seekh kebab', image_path = '/uploads/menu/Seekh_kebab.jpg' WHERE item_code = 'SI0227' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Fried chicken', image_path = '/uploads/menu/Fried_chicken.jpg' WHERE item_code = 'SI0229' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kola urundai', image_path = '/uploads/menu/Kola_urundai.jpg' WHERE item_code = 'SI0230' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Cutlet', image_path = '/uploads/menu/Cutlet.jpg' WHERE item_code = 'SI0232' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Prawn', image_path = '/uploads/menu/Prawn.jpg' WHERE item_code = 'SI0233' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Fish finger', image_path = '/uploads/menu/Fish_finger.jpg' WHERE item_code = 'SI0234' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Popcorn chicken', image_path = '/uploads/menu/Popcorn_chicken.jpg' WHERE item_code = 'SI0235' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Parotta', image_path = '/uploads/menu/Parotta.jpg' WHERE item_code = 'SI0236' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Parotta', image_path = '/uploads/menu/Parotta.jpg' WHERE item_code = 'SI0237' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kothu parotta', image_path = '/uploads/menu/Kothu_parotta.jpg' WHERE item_code = 'SI0238' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kothu parotta', image_path = '/uploads/menu/Kothu_parotta.jpg' WHERE item_code = 'SI0239' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kothu parotta', image_path = '/uploads/menu/Kothu_parotta.jpg' WHERE item_code = 'SI0240' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kothu parotta', image_path = '/uploads/menu/Kothu_parotta.jpg' WHERE item_code = 'SI0241' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Parotta', image_path = '/uploads/menu/Parotta.jpg' WHERE item_code = 'SI0242' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chapati', image_path = '/uploads/menu/Chapati.jpg' WHERE item_code = 'SI0243' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Phulka', image_path = '/uploads/menu/Phulka.jpg' WHERE item_code = 'SI0244' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Naan', image_path = '/uploads/menu/Naan.jpg' WHERE item_code = 'SI0245' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Naan', image_path = '/uploads/menu/Naan.jpg' WHERE item_code = 'SI0246' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Naan', image_path = '/uploads/menu/Naan.jpg' WHERE item_code = 'SI0247' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kulcha', image_path = '/uploads/menu/Kulcha.jpg' WHERE item_code = 'SI0248' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Roti', image_path = '/uploads/menu/Roti.jpg' WHERE item_code = 'SI0249' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Rumali roti', image_path = '/uploads/menu/Rumali_roti.jpg' WHERE item_code = 'SI0250' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Laccha paratha', image_path = '/uploads/menu/Laccha_paratha.jpg' WHERE item_code = 'SI0251' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Aloo paratha', image_path = '/uploads/menu/Aloo_paratha.jpg' WHERE item_code = 'SI0252' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Bhatoora', image_path = '/uploads/menu/Bhatoora.jpg' WHERE item_code = 'SI0253' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Jolada rotti', image_path = '/uploads/menu/Jolada_rotti.jpg' WHERE item_code = 'SI0254' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Appam', image_path = '/uploads/menu/Appam.jpg' WHERE item_code = 'SI0255' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Ragi', image_path = '/uploads/menu/Ragi.jpg' WHERE item_code = 'SI0256' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Parotta', image_path = '/uploads/menu/Parotta.jpg' WHERE item_code = 'SI0257' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Fried rice', image_path = '/uploads/menu/Fried_rice.jpg' WHERE item_code = 'SI0258' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Fried rice', image_path = '/uploads/menu/Fried_rice.jpg' WHERE item_code = 'SI0259' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Fried rice', image_path = '/uploads/menu/Fried_rice.jpg' WHERE item_code = 'SI0260' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chow mein', image_path = '/uploads/menu/Chow_mein.jpg' WHERE item_code = 'SI0261' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Hakka noodles', image_path = '/uploads/menu/Hakka_noodles.jpg' WHERE item_code = 'SI0262' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chow mein', image_path = '/uploads/menu/Chow_mein.jpg' WHERE item_code = 'SI0263' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chow mein', image_path = '/uploads/menu/Chow_mein.jpg' WHERE item_code = 'SI0264' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Manchurian (dish)', image_path = '/uploads/menu/Manchurian_dish.jpg' WHERE item_code = 'SI0265' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Gobi Manchurian', image_path = '/uploads/menu/Gobi_Manchurian.jpg' WHERE item_code = 'SI0266' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'American chop suey', image_path = '/uploads/menu/American_chop_suey.jpg' WHERE item_code = 'SI0267' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Manchow soup', image_path = '/uploads/menu/Manchow_soup.jpg' WHERE item_code = 'SI0268' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Hot and sour soup', image_path = '/uploads/menu/Hot_and_sour_soup.jpg' WHERE item_code = 'SI0269' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Corn soup', image_path = '/uploads/menu/Corn_soup.jpg' WHERE item_code = 'SI0270' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Manchow soup', image_path = '/uploads/menu/Manchow_soup.jpg' WHERE item_code = 'SI0271' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Fried rice', image_path = '/uploads/menu/Fried_rice.jpg' WHERE item_code = 'SI0272' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chow mein', image_path = '/uploads/menu/Chow_mein.jpg' WHERE item_code = 'SI0273' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chow mein', image_path = '/uploads/menu/Chow_mein.jpg' WHERE item_code = 'SI0274' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chilli chicken', image_path = '/uploads/menu/Chilli_chicken.jpg' WHERE item_code = 'SI0275' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pani puri', image_path = '/uploads/menu/Pani_puri.jpg' WHERE item_code = 'SI0276' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Sev puri', image_path = '/uploads/menu/Sev_puri.jpg' WHERE item_code = 'SI0277' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Bhelpuri', image_path = '/uploads/menu/Bhelpuri.jpg' WHERE item_code = 'SI0278' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dahi puri', image_path = '/uploads/menu/Dahi_puri.jpg' WHERE item_code = 'SI0279' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Masala puri', image_path = '/uploads/menu/Masala_puri.jpg' WHERE item_code = 'SI0280' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Samosa', image_path = '/uploads/menu/Samosa.jpg' WHERE item_code = 'SI0281' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pav bhaji', image_path = '/uploads/menu/Pav_bhaji.jpg' WHERE item_code = 'SI0282' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Vada pav', image_path = '/uploads/menu/Vada_pav.jpg' WHERE item_code = 'SI0283' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dabeli', image_path = '/uploads/menu/Dabeli.jpg' WHERE item_code = 'SI0284' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kachori', image_path = '/uploads/menu/Kachori.jpg' WHERE item_code = 'SI0285' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Aloo tikki', image_path = '/uploads/menu/Aloo_tikki.jpg' WHERE item_code = 'SI0286' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Papri chaat', image_path = '/uploads/menu/Papri_chaat.jpg' WHERE item_code = 'SI0287' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dhokla', image_path = '/uploads/menu/Dhokla.jpg' WHERE item_code = 'SI0288' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Khandvi', image_path = '/uploads/menu/Khandvi.jpg' WHERE item_code = 'SI0289' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Sundal', image_path = '/uploads/menu/Sundal.jpg' WHERE item_code = 'SI0290' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pazham pori', image_path = '/uploads/menu/Pazham_pori.jpg' WHERE item_code = 'SI0291' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Unni appam', image_path = '/uploads/menu/Unni_appam.jpg' WHERE item_code = 'SI0292' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Ela ada', image_path = '/uploads/menu/Ela_ada.jpg' WHERE item_code = 'SI0293' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Punugulu', image_path = '/uploads/menu/Punugulu.jpg' WHERE item_code = 'SI0294' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Puff pastry', image_path = '/uploads/menu/Puff_pastry.jpg' WHERE item_code = 'SI0295' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Puff pastry', image_path = '/uploads/menu/Puff_pastry.jpg' WHERE item_code = 'SI0296' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Puff pastry', image_path = '/uploads/menu/Puff_pastry.jpg' WHERE item_code = 'SI0297' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Mixture (snack)', image_path = '/uploads/menu/Mixture_snack.jpg' WHERE item_code = 'SI0298' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Misal pav', image_path = '/uploads/menu/Misal_pav.jpg' WHERE item_code = 'SI0299' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Poha (food)', image_path = '/uploads/menu/Poha_food.jpg' WHERE item_code = 'SI0300' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Samosa', image_path = '/uploads/menu/Samosa.jpg' WHERE item_code = 'SI0301' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Rasam', image_path = '/uploads/menu/Rasam.jpg' WHERE item_code = 'SI0304' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Rasam', image_path = '/uploads/menu/Rasam.jpg' WHERE item_code = 'SI0305' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Paya', image_path = '/uploads/menu/Paya.jpg' WHERE item_code = 'SI0306' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chicken soup', image_path = '/uploads/menu/Chicken_soup.jpg' WHERE item_code = 'SI0307' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Curd', image_path = '/uploads/menu/Curd.jpg' WHERE item_code = 'SI0310' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Raita', image_path = '/uploads/menu/Raita.jpg' WHERE item_code = 'SI0311' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Raita', image_path = '/uploads/menu/Raita.jpg' WHERE item_code = 'SI0312' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Papadum', image_path = '/uploads/menu/Papadum.jpg' WHERE item_code = 'SI0313' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Indian pickle', image_path = '/uploads/menu/Indian_pickle.jpg' WHERE item_code = 'SI0314' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kachumber', image_path = '/uploads/menu/Kachumber.jpg' WHERE item_code = 'SI0317' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chutney', image_path = '/uploads/menu/Chutney.jpg' WHERE item_code = 'SI0318' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Sambar (dish)', image_path = '/uploads/menu/Sambar_dish.jpg' WHERE item_code = 'SI0319' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Gunpowder (spice mix)', image_path = '/uploads/menu/Gunpowder_spice_mix.jpg' WHERE item_code = 'SI0320' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Papadum', image_path = '/uploads/menu/Papadum.jpg' WHERE item_code = 'SI0321' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Gulab jamun', image_path = '/uploads/menu/Gulab_jamun.jpg' WHERE item_code = 'SI0322' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Ras malai', image_path = '/uploads/menu/Ras_malai.jpg' WHERE item_code = 'SI0323' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Mysore pak', image_path = '/uploads/menu/Mysore_pak.jpg' WHERE item_code = 'SI0324' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Payasam', image_path = '/uploads/menu/Payasam.jpg' WHERE item_code = 'SI0325' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Ada pradhaman', image_path = '/uploads/menu/Ada_pradhaman.jpg' WHERE item_code = 'SI0326' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Double ka meetha', image_path = '/uploads/menu/Double_ka_meetha.jpg' WHERE item_code = 'SI0327' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Qubani ka meetha', image_path = '/uploads/menu/Qubani_ka_meetha.jpg' WHERE item_code = 'SI0328' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Jalebi', image_path = '/uploads/menu/Jalebi.jpg' WHERE item_code = 'SI0329' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Halva', image_path = '/uploads/menu/Halva.jpg' WHERE item_code = 'SI0330' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Gajar ka halwa', image_path = '/uploads/menu/Gajar_ka_halwa.jpg' WHERE item_code = 'SI0331' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Ada pradhaman', image_path = '/uploads/menu/Ada_pradhaman.jpg' WHERE item_code = 'SI0332' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Puran poli', image_path = '/uploads/menu/Puran_poli.jpg' WHERE item_code = 'SI0333' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kozhukkattai', image_path = '/uploads/menu/Kozhukkattai.jpg' WHERE item_code = 'SI0334' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Laddu', image_path = '/uploads/menu/Laddu.jpg' WHERE item_code = 'SI0335' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Boondi laddu', image_path = '/uploads/menu/Boondi_laddu.jpg' WHERE item_code = 'SI0336' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Tirunelveli halwa', image_path = '/uploads/menu/Tirunelveli_halwa.jpg' WHERE item_code = 'SI0337' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Ice cream', image_path = '/uploads/menu/Ice_cream.jpg' WHERE item_code = 'SI0338' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kulfi', image_path = '/uploads/menu/Kulfi.jpg' WHERE item_code = 'SI0339' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Falooda', image_path = '/uploads/menu/Falooda.jpg' WHERE item_code = 'SI0340' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Fruit salad', image_path = '/uploads/menu/Fruit_salad.jpg' WHERE item_code = 'SI0341' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Sheer khurma', image_path = '/uploads/menu/Sheer_khurma.jpg' WHERE item_code = 'SI0342' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kheer', image_path = '/uploads/menu/Kheer.jpg' WHERE item_code = 'SI0343' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Rasgulla', image_path = '/uploads/menu/Rasgulla.jpg' WHERE item_code = 'SI0344' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Bebinca', image_path = '/uploads/menu/Bebinca.jpg' WHERE item_code = 'SI0346' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Sandesh (confectionery)', image_path = '/uploads/menu/Sandesh_confectionery.jpg' WHERE item_code = 'SI0347' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Barfi', image_path = '/uploads/menu/Barfi.jpg' WHERE item_code = 'SI0348' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Payasam', image_path = '/uploads/menu/Payasam.jpg' WHERE item_code = 'SI0349' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Filter coffee', image_path = '/uploads/menu/Filter_coffee.jpg' WHERE item_code = 'SI0350' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Masala chai', image_path = '/uploads/menu/Masala_chai.jpg' WHERE item_code = 'SI0351' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Masala chai', image_path = '/uploads/menu/Masala_chai.jpg' WHERE item_code = 'SI0352' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Masala chai', image_path = '/uploads/menu/Masala_chai.jpg' WHERE item_code = 'SI0353' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Tea', image_path = '/uploads/menu/Tea.jpg' WHERE item_code = 'SI0354' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Black coffee', image_path = '/uploads/menu/Black_coffee.jpg' WHERE item_code = 'SI0355' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Instant coffee', image_path = '/uploads/menu/Instant_coffee.jpg' WHERE item_code = 'SI0356' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Badam milk', image_path = '/uploads/menu/Badam_milk.jpg' WHERE item_code = 'SI0357' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Horlicks', image_path = '/uploads/menu/Horlicks.jpg' WHERE item_code = 'SI0358' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Boost (drink)', image_path = '/uploads/menu/Boost_drink.jpg' WHERE item_code = 'SI0359' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Milk', image_path = '/uploads/menu/Milk.jpg' WHERE item_code = 'SI0360' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Green tea', image_path = '/uploads/menu/Green_tea.jpg' WHERE item_code = 'SI0361' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Sukku malli coffee', image_path = '/uploads/menu/Sukku_malli_coffee.jpg' WHERE item_code = 'SI0362' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Irani chai', image_path = '/uploads/menu/Irani_chai.jpg' WHERE item_code = 'SI0363' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kashayam', image_path = '/uploads/menu/Kashayam.jpg' WHERE item_code = 'SI0364' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Buttermilk', image_path = '/uploads/menu/Buttermilk.jpg' WHERE item_code = 'SI0365' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chaas', image_path = '/uploads/menu/Chaas.jpg' WHERE item_code = 'SI0366' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Lassi', image_path = '/uploads/menu/Lassi.jpg' WHERE item_code = 'SI0367' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Lassi', image_path = '/uploads/menu/Lassi.jpg' WHERE item_code = 'SI0368' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Rose milk', image_path = '/uploads/menu/Rose_milk.jpg' WHERE item_code = 'SI0369' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Badam milk', image_path = '/uploads/menu/Badam_milk.jpg' WHERE item_code = 'SI0370' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Nannari', image_path = '/uploads/menu/Nannari.jpg' WHERE item_code = 'SI0371' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Jigarthanda', image_path = '/uploads/menu/Jigarthanda.jpg' WHERE item_code = 'SI0372' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Lime soda', image_path = '/uploads/menu/Lime_soda.jpg' WHERE item_code = 'SI0373' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Limeade', image_path = '/uploads/menu/Limeade.jpg' WHERE item_code = 'SI0374' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Coconut water', image_path = '/uploads/menu/Coconut_water.jpg' WHERE item_code = 'SI0375' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Sugarcane juice', image_path = '/uploads/menu/Sugarcane_juice.jpg' WHERE item_code = 'SI0376' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Watermelon', image_path = '/uploads/menu/Watermelon.jpg' WHERE item_code = 'SI0377' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Orange juice', image_path = '/uploads/menu/Orange_juice.jpg' WHERE item_code = 'SI0378' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pineapple', image_path = '/uploads/menu/Pineapple.jpg' WHERE item_code = 'SI0379' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Sweet lime', image_path = '/uploads/menu/Sweet_lime.jpg' WHERE item_code = 'SI0380' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Mango', image_path = '/uploads/menu/Mango.jpg' WHERE item_code = 'SI0381' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Grape juice', image_path = '/uploads/menu/Grape_juice.jpg' WHERE item_code = 'SI0382' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Pomegranate juice', image_path = '/uploads/menu/Pomegranate_juice.jpg' WHERE item_code = 'SI0383' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Cantaloupe', image_path = '/uploads/menu/Cantaloupe.jpg' WHERE item_code = 'SI0384' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Juice', image_path = '/uploads/menu/Juice.jpg' WHERE item_code = 'SI0385' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Milkshake', image_path = '/uploads/menu/Milkshake.jpg' WHERE item_code = 'SI0386' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Milkshake', image_path = '/uploads/menu/Milkshake.jpg' WHERE item_code = 'SI0387' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Milkshake', image_path = '/uploads/menu/Milkshake.jpg' WHERE item_code = 'SI0388' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Iced coffee', image_path = '/uploads/menu/Iced_coffee.jpg' WHERE item_code = 'SI0389' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Thandai', image_path = '/uploads/menu/Thandai.jpg' WHERE item_code = 'SI0390' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Soft drink', image_path = '/uploads/menu/Soft_drink.jpg' WHERE item_code = 'SI0391' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Bottled water', image_path = '/uploads/menu/Bottled_water.jpg' WHERE item_code = 'SI0392' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Soda', image_path = '/uploads/menu/Soda.jpg' WHERE item_code = 'SI0393' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Panakam', image_path = '/uploads/menu/Panakam.jpg' WHERE item_code = 'SI0394' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Ragi malt', image_path = '/uploads/menu/Ragi_malt.jpg' WHERE item_code = 'SI0395' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kokum', image_path = '/uploads/menu/Kokum.jpg' WHERE item_code = 'SI0396' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Buttermilk', image_path = '/uploads/menu/Buttermilk.jpg' WHERE item_code = 'SI0397' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Sarson da saag', image_path = '/uploads/menu/Sarson_da_saag.jpg' WHERE item_code = 'SI0398' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kulcha', image_path = '/uploads/menu/Kulcha.jpg' WHERE item_code = 'SI0399' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chole bhature', image_path = '/uploads/menu/Chole_bhature.jpg' WHERE item_code = 'SI0400' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Rajma chawal', image_path = '/uploads/menu/Rajma_chawal.jpg' WHERE item_code = 'SI0401' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kadhi', image_path = '/uploads/menu/Kadhi.jpg' WHERE item_code = 'SI0402' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dal baati churma', image_path = '/uploads/menu/Dal_baati_churma.jpg' WHERE item_code = 'SI0403' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Laal maas', image_path = '/uploads/menu/Laal_maas.jpg' WHERE item_code = 'SI0404' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Gatte ki sabzi', image_path = '/uploads/menu/Gatte_ki_sabzi.jpg' WHERE item_code = 'SI0405' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Thepla', image_path = '/uploads/menu/Thepla.jpg' WHERE item_code = 'SI0406' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Undhiyu', image_path = '/uploads/menu/Undhiyu.jpg' WHERE item_code = 'SI0407' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Fafda', image_path = '/uploads/menu/Fafda.jpg' WHERE item_code = 'SI0408' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Litti chokha', image_path = '/uploads/menu/Litti_chokha.jpg' WHERE item_code = 'SI0409' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Macher jhol', image_path = '/uploads/menu/Macher_jhol.jpg' WHERE item_code = 'SI0410' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Hilsa', image_path = '/uploads/menu/Hilsa.jpg' WHERE item_code = 'SI0411' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kosha mangsho', image_path = '/uploads/menu/Kosha_mangsho.jpg' WHERE item_code = 'SI0412' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Luchi', image_path = '/uploads/menu/Luchi.jpg' WHERE item_code = 'SI0413' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Momo (food)', image_path = '/uploads/menu/Momo_food.jpg' WHERE item_code = 'SI0414' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Momo (food)', image_path = '/uploads/menu/Momo_food.jpg' WHERE item_code = 'SI0415' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Thukpa', image_path = '/uploads/menu/Thukpa.jpg' WHERE item_code = 'SI0416' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Cafreal', image_path = '/uploads/menu/Cafreal.jpg' WHERE item_code = 'SI0417' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Vindaloo', image_path = '/uploads/menu/Vindaloo.jpg' WHERE item_code = 'SI0418' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Sorpotel', image_path = '/uploads/menu/Sorpotel.jpg' WHERE item_code = 'SI0419' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dhansak', image_path = '/uploads/menu/Dhansak.jpg' WHERE item_code = 'SI0420' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dum aloo', image_path = '/uploads/menu/Dum_aloo.jpg' WHERE item_code = 'SI0421' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Gushtaba', image_path = '/uploads/menu/Gushtaba.jpg' WHERE item_code = 'SI0422' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Khichdi', image_path = '/uploads/menu/Khichdi.jpg' WHERE item_code = 'SI0424' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Khichdi', image_path = '/uploads/menu/Khichdi.jpg' WHERE item_code = 'SI0425' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Paneer', image_path = '/uploads/menu/Paneer.jpg' WHERE item_code = 'SI0426' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Sandwich', image_path = '/uploads/menu/Sandwich.jpg' WHERE item_code = 'SI0427' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Egg bhurji', image_path = '/uploads/menu/Egg_bhurji.jpg' WHERE item_code = 'SI0428' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Egg curry', image_path = '/uploads/menu/Egg_curry.jpg' WHERE item_code = 'SI0429' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Kahwa', image_path = '/uploads/menu/Kahwa.jpg' WHERE item_code = 'SI0430' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Paneer tikka', image_path = '/uploads/menu/Paneer_tikka.jpg' WHERE item_code = 'FI001' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Chicken 65', image_path = '/uploads/menu/Chicken_65.jpg' WHERE item_code = 'FI002' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Spring roll', image_path = '/uploads/menu/Spring_roll.jpg' WHERE item_code = 'FI003' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Paneer makhani', image_path = '/uploads/menu/Paneer_makhani.jpg' WHERE item_code = 'FI004' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Butter chicken', image_path = '/uploads/menu/Butter_chicken.jpg' WHERE item_code = 'FI005' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Dal', image_path = '/uploads/menu/Dal.jpg' WHERE item_code = 'FI006' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Biryani', image_path = '/uploads/menu/Biryani.jpg' WHERE item_code = 'FI007' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Biryani', image_path = '/uploads/menu/Biryani.jpg' WHERE item_code = 'FI008' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Naan', image_path = '/uploads/menu/Naan.jpg' WHERE item_code = 'FI009' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Tandoor bread', image_path = '/uploads/menu/Tandoor_bread.jpg' WHERE item_code = 'FI010' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Masala chai', image_path = '/uploads/menu/Masala_chai.jpg' WHERE item_code = 'FI011' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Lemonade', image_path = '/uploads/menu/Lemonade.jpg' WHERE item_code = 'FI012' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Gulab jamun', image_path = '/uploads/menu/Gulab_jamun.jpg' WHERE item_code = 'FI013' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');
UPDATE menu.food_item_master SET image_source = 'Ice cream', image_path = '/uploads/menu/Ice_cream.jpg' WHERE item_code = 'FI014' AND (image_path IS NULL OR image_path LIKE '/uploads/menu/%');

COMMIT;
