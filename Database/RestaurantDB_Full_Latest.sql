/* RESTAURANT MANAGEMENT - FULL LATEST DATABASE SCRIPT (fresh install): base + phase 2 + phase 3. Run once in an empty RestaurantDB. */
/* =====================================================================
   RESTAURANT MANAGEMENT SYSTEM - PostgreSQL database script
   ---------------------------------------------------------------------
   1. In pgAdmin create an empty database:   CREATE DATABASE "RestaurantDB";
   2. Open a Query Tool on RestaurantDB and run this whole file once.
   3. Put your server details in appsettings.json (DefaultConnection).

   Default login after running:  admin / Admin@123   (change it after first login)

   Sections
     1. Schemas
     2. Restaurant profile
     3. MASTER tables (managed by the web application screens)
     4. Users, menu variants, orders, kitchen, billing, payments,
        inventory, purchase, HR attendance, expenses, feedback, audit
     5. Reporting views
     6. Starter (seed) data
   ===================================================================== */

-- 1. SCHEMAS -------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS admin;
CREATE SCHEMA IF NOT EXISTS menu;
CREATE SCHEMA IF NOT EXISTS orders;
CREATE SCHEMA IF NOT EXISTS billing;
CREATE SCHEMA IF NOT EXISTS payments;
CREATE SCHEMA IF NOT EXISTS inventory;
CREATE SCHEMA IF NOT EXISTS purchase;
CREATE SCHEMA IF NOT EXISTS hr;
CREATE SCHEMA IF NOT EXISTS crm;
CREATE SCHEMA IF NOT EXISTS expense;
CREATE SCHEMA IF NOT EXISTS reports;

-- 2. RESTAURANT PROFILE --------------------------------------------------
CREATE TABLE IF NOT EXISTS admin.restaurant_master
(
    restaurant_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    restaurant_name VARCHAR(150) NOT NULL,
    legal_name      VARCHAR(200),
    gst_number      VARCHAR(20),
    fssai_number    VARCHAR(20),
    phone           VARCHAR(20),
    email           VARCHAR(100),
    address         TEXT,
    currency_symbol VARCHAR(5) NOT NULL DEFAULT '₹',
    logo_path       VARCHAR(500),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_on      TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO admin.restaurant_master (restaurant_name, legal_name)
SELECT 'My Restaurant', 'My Restaurant'
WHERE NOT EXISTS (SELECT 1 FROM admin.restaurant_master);

-- 3. MASTER TABLES -------------------------------------------------------
CREATE TABLE IF NOT EXISTS admin.role_master
(
    role_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL,
    description VARCHAR(200),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_role_master_role_name UNIQUE (role_name)
);


CREATE TABLE IF NOT EXISTS admin.branch_master
(
    branch_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    restaurant_id INT NOT NULL DEFAULT 1 REFERENCES admin.restaurant_master(restaurant_id),
    branch_name VARCHAR(100) NOT NULL,
    branch_code VARCHAR(20) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100),
    city VARCHAR(60),
    state VARCHAR(60),
    pincode VARCHAR(10),
    gst_number VARCHAR(20),
    fssai_number VARCHAR(20),
    address TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_branch_master_branch_name UNIQUE (branch_name),
    CONSTRAINT uq_branch_master_branch_code UNIQUE (branch_code)
);


CREATE TABLE IF NOT EXISTS orders.floor_master
(
    floor_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    floor_name VARCHAR(100) NOT NULL,
    branch_id INT REFERENCES admin.branch_master(branch_id),
    description VARCHAR(200),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_floor_master_floor_name UNIQUE (floor_name)
);
CREATE INDEX IF NOT EXISTS ix_floor_master_branch_id ON orders.floor_master (branch_id);

CREATE TABLE IF NOT EXISTS orders.table_master
(
    dining_table_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    floor_id INT NOT NULL REFERENCES orders.floor_master(floor_id),
    table_number VARCHAR(20) NOT NULL,
    capacity INT NOT NULL DEFAULT 4,
    status VARCHAR(30) NOT NULL DEFAULT 'Available',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_table_master_status CHECK (status IN ('Available', 'Occupied', 'Reserved', 'Cleaning')),
    CONSTRAINT uq_table_master_floor_id_table_number UNIQUE (floor_id, table_number)
);
CREATE INDEX IF NOT EXISTS ix_table_master_floor_id ON orders.table_master (floor_id);

CREATE TABLE IF NOT EXISTS orders.kitchen_station
(
    kitchen_station_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    station_name VARCHAR(100) NOT NULL,
    printer_name VARCHAR(100),
    description VARCHAR(200),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_kitchen_station_station_name UNIQUE (station_name)
);


CREATE TABLE IF NOT EXISTS menu.category_master
(
    category_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    description VARCHAR(200),
    display_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_category_master_category_name UNIQUE (category_name)
);


CREATE TABLE IF NOT EXISTS billing.tax_master
(
    tax_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tax_name VARCHAR(100) NOT NULL,
    tax_percentage NUMERIC(12,2) NOT NULL DEFAULT 0,
    is_inclusive BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_tax_master_tax_name UNIQUE (tax_name)
);


CREATE TABLE IF NOT EXISTS menu.food_item_master
(
    food_item_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    image_path VARCHAR(500),
    item_code VARCHAR(20),
    food_name VARCHAR(150) NOT NULL,
    category_id INT NOT NULL REFERENCES menu.category_master(category_id),
    food_type VARCHAR(30) NOT NULL DEFAULT 'Veg',
    price NUMERIC(12,2) NOT NULL DEFAULT 0,
    tax_id INT REFERENCES billing.tax_master(tax_id),
    kitchen_station_id INT REFERENCES orders.kitchen_station(kitchen_station_id),
    preparation_time INT,
    description TEXT,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_food_item_master_item_code UNIQUE (item_code),
    CONSTRAINT ck_food_item_master_food_type CHECK (food_type IN ('Veg', 'Non-Veg', 'Egg', 'Vegan', 'Beverage'))
);
CREATE INDEX IF NOT EXISTS ix_food_item_master_category_id ON menu.food_item_master (category_id);
CREATE INDEX IF NOT EXISTS ix_food_item_master_tax_id ON menu.food_item_master (tax_id);
CREATE INDEX IF NOT EXISTS ix_food_item_master_kitchen_station_id ON menu.food_item_master (kitchen_station_id);

CREATE TABLE IF NOT EXISTS menu.addon_master
(
    addon_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    addon_name VARCHAR(100) NOT NULL,
    price NUMERIC(12,2) NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_addon_master_addon_name UNIQUE (addon_name)
);


CREATE TABLE IF NOT EXISTS hr.designation_master
(
    designation_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    designation_name VARCHAR(100) NOT NULL,
    description VARCHAR(200),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_designation_master_designation_name UNIQUE (designation_name)
);


CREATE TABLE IF NOT EXISTS hr.shift_master
(
    shift_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    shift_name VARCHAR(100) NOT NULL,
    start_time TIME NOT NULL DEFAULT '00:00',
    end_time TIME NOT NULL DEFAULT '00:00',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_shift_master_shift_name UNIQUE (shift_name)
);


CREATE TABLE IF NOT EXISTS hr.employee_master
(
    employee_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_code VARCHAR(20) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    designation_id INT NOT NULL REFERENCES hr.designation_master(designation_id),
    shift_id INT REFERENCES hr.shift_master(shift_id),
    branch_id INT REFERENCES admin.branch_master(branch_id),
    phone VARCHAR(20),
    email VARCHAR(100),
    gender VARCHAR(30),
    date_of_birth DATE,
    joining_date DATE,
    salary NUMERIC(12,2),
    address TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_employee_master_employee_code UNIQUE (employee_code),
    CONSTRAINT ck_employee_master_gender CHECK (gender IN ('Male', 'Female', 'Other'))
);
CREATE INDEX IF NOT EXISTS ix_employee_master_designation_id ON hr.employee_master (designation_id);
CREATE INDEX IF NOT EXISTS ix_employee_master_shift_id ON hr.employee_master (shift_id);
CREATE INDEX IF NOT EXISTS ix_employee_master_branch_id ON hr.employee_master (branch_id);

CREATE TABLE IF NOT EXISTS crm.customer_master
(
    customer_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(100),
    birth_date DATE,
    loyalty_points INT NOT NULL DEFAULT 0,
    address TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_customer_master_phone UNIQUE (phone)
);


CREATE TABLE IF NOT EXISTS inventory.unit_master
(
    unit_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    unit_name VARCHAR(50) NOT NULL,
    short_name VARCHAR(10) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_unit_master_unit_name UNIQUE (unit_name),
    CONSTRAINT uq_unit_master_short_name UNIQUE (short_name)
);


CREATE TABLE IF NOT EXISTS inventory.ingredient_master
(
    ingredient_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ingredient_name VARCHAR(100) NOT NULL,
    unit_id INT NOT NULL REFERENCES inventory.unit_master(unit_id),
    reorder_level NUMERIC(12,2) NOT NULL DEFAULT 0,
    cost_per_unit NUMERIC(12,2) NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ingredient_master_ingredient_name UNIQUE (ingredient_name)
);
CREATE INDEX IF NOT EXISTS ix_ingredient_master_unit_id ON inventory.ingredient_master (unit_id);

CREATE TABLE IF NOT EXISTS purchase.supplier_master
(
    supplier_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_name VARCHAR(150) NOT NULL,
    contact_person VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(100),
    gst_number VARCHAR(20),
    address TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now()
);


CREATE TABLE IF NOT EXISTS billing.discount_master
(
    discount_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    discount_name VARCHAR(100) NOT NULL,
    discount_code VARCHAR(30),
    discount_type VARCHAR(30) NOT NULL DEFAULT 'Percentage',
    discount_value NUMERIC(12,2) NOT NULL DEFAULT 0,
    min_order_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    valid_from DATE,
    valid_to DATE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_discount_master_discount_name UNIQUE (discount_name),
    CONSTRAINT uq_discount_master_discount_code UNIQUE (discount_code),
    CONSTRAINT ck_discount_master_discount_type CHECK (discount_type IN ('Percentage', 'Flat'))
);


CREATE TABLE IF NOT EXISTS payments.payment_mode_master
(
    payment_mode_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mode_name VARCHAR(50) NOT NULL,
    mode_type VARCHAR(30) NOT NULL DEFAULT 'Cash',
    requires_reference BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_payment_mode_master_mode_name UNIQUE (mode_name),
    CONSTRAINT ck_payment_mode_master_mode_type CHECK (mode_type IN ('Cash', 'Card', 'UPI', 'Online', 'Wallet', 'Other'))
);


CREATE TABLE IF NOT EXISTS expense.expense_category_master
(
    expense_category_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    expense_category_name VARCHAR(100) NOT NULL,
    description VARCHAR(200),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_on TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_expense_category_master_expense_category_name UNIQUE (expense_category_name)
);


-- 4. USERS, TRANSACTIONS AND OTHER TABLES --------------------------------
CREATE TABLE IF NOT EXISTS admin.user_master
(
    user_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_name     VARCHAR(50)  NOT NULL,
    full_name     VARCHAR(100) NOT NULL,
    password_hash VARCHAR(500) NOT NULL,
    role_id       INT NOT NULL REFERENCES admin.role_master(role_id),
    branch_id     INT REFERENCES admin.branch_master(branch_id),
    last_login_on TIMESTAMPTZ,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_on    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_master_user_name UNIQUE (user_name)
);

CREATE TABLE IF NOT EXISTS admin.audit_log
(
    audit_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     INT REFERENCES admin.user_master(user_id),
    action      VARCHAR(50)  NOT NULL,
    entity_name VARCHAR(100),
    entity_id   VARCHAR(50),
    details     TEXT,
    created_on  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Menu: variants (Half / Full) and add-on mapping
CREATE TABLE IF NOT EXISTS menu.food_variant
(
    variant_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    food_item_id INT NOT NULL REFERENCES menu.food_item_master(food_item_id) ON DELETE CASCADE,
    variant_name VARCHAR(50) NOT NULL,
    price        NUMERIC(12,2) NOT NULL DEFAULT 0,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_food_variant UNIQUE (food_item_id, variant_name)
);

CREATE TABLE IF NOT EXISTS menu.food_addon_mapping
(
    food_item_id INT NOT NULL REFERENCES menu.food_item_master(food_item_id) ON DELETE CASCADE,
    addon_id     INT NOT NULL REFERENCES menu.addon_master(addon_id) ON DELETE CASCADE,
    PRIMARY KEY (food_item_id, addon_id)
);

-- Orders
CREATE TABLE IF NOT EXISTS orders.order_master
(
    order_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_number    VARCHAR(30) NOT NULL,
    branch_id       INT REFERENCES admin.branch_master(branch_id),
    order_type      VARCHAR(20) NOT NULL DEFAULT 'Dine-In',
    dining_table_id INT REFERENCES orders.table_master(dining_table_id),
    customer_id     INT REFERENCES crm.customer_master(customer_id),
    waiter_id       INT REFERENCES hr.employee_master(employee_id),
    guest_count     INT NOT NULL DEFAULT 1,
    status          VARCHAR(20) NOT NULL DEFAULT 'New',
    sub_total       NUMERIC(12,2) NOT NULL DEFAULT 0,
    tax_amount      NUMERIC(12,2) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    delivery_charge NUMERIC(12,2) NOT NULL DEFAULT 0,
    grand_total     NUMERIC(12,2) NOT NULL DEFAULT 0,
    delivery_address TEXT,
    notes           TEXT,
    created_by      INT REFERENCES admin.user_master(user_id),
    created_on      TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_on       TIMESTAMPTZ,
    CONSTRAINT uq_order_master_number UNIQUE (order_number),
    CONSTRAINT ck_order_type   CHECK (order_type IN ('Dine-In','Takeaway','Delivery','Online')),
    CONSTRAINT ck_order_status CHECK (status IN ('New','In Kitchen','Ready','Served','Billed','Completed','Cancelled'))
);
CREATE INDEX IF NOT EXISTS ix_order_master_status  ON orders.order_master (status);
CREATE INDEX IF NOT EXISTS ix_order_master_created ON orders.order_master (created_on);
CREATE INDEX IF NOT EXISTS ix_order_master_table   ON orders.order_master (dining_table_id);

CREATE TABLE IF NOT EXISTS orders.order_items
(
    order_item_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id           BIGINT NOT NULL REFERENCES orders.order_master(order_id) ON DELETE CASCADE,
    food_item_id       INT NOT NULL REFERENCES menu.food_item_master(food_item_id),
    variant_id         INT REFERENCES menu.food_variant(variant_id),
    item_name          VARCHAR(150) NOT NULL,
    quantity           INT NOT NULL CHECK (quantity > 0),
    unit_price         NUMERIC(12,2) NOT NULL,
    tax_percentage     NUMERIC(5,2) NOT NULL DEFAULT 0,
    line_total         NUMERIC(12,2) NOT NULL,
    kitchen_station_id INT REFERENCES orders.kitchen_station(kitchen_station_id),
    item_status        VARCHAR(20) NOT NULL DEFAULT 'New',
    notes              VARCHAR(300),
    CONSTRAINT ck_order_item_status CHECK (item_status IN ('New','Preparing','Ready','Served','Cancelled'))
);
CREATE INDEX IF NOT EXISTS ix_order_items_order ON orders.order_items (order_id);

CREATE TABLE IF NOT EXISTS orders.order_item_addons
(
    order_item_id BIGINT NOT NULL REFERENCES orders.order_items(order_item_id) ON DELETE CASCADE,
    addon_id      INT NOT NULL REFERENCES menu.addon_master(addon_id),
    price         NUMERIC(12,2) NOT NULL DEFAULT 0,
    PRIMARY KEY (order_item_id, addon_id)
);

CREATE TABLE IF NOT EXISTS orders.order_status_history
(
    history_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id   BIGINT NOT NULL REFERENCES orders.order_master(order_id) ON DELETE CASCADE,
    old_status VARCHAR(20),
    new_status VARCHAR(20) NOT NULL,
    changed_by INT REFERENCES admin.user_master(user_id),
    changed_on TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS orders.kitchen_order
(
    kitchen_order_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id           BIGINT NOT NULL REFERENCES orders.order_master(order_id) ON DELETE CASCADE,
    kitchen_station_id INT REFERENCES orders.kitchen_station(kitchen_station_id),
    status             VARCHAR(20) NOT NULL DEFAULT 'Pending',
    created_on         TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_on         TIMESTAMPTZ,
    ready_on           TIMESTAMPTZ,
    CONSTRAINT ck_kitchen_order_status CHECK (status IN ('Pending','Preparing','Ready','Served','Cancelled'))
);
CREATE INDEX IF NOT EXISTS ix_kitchen_order_status ON orders.kitchen_order (status);

-- Billing
CREATE TABLE IF NOT EXISTS billing.invoice_master
(
    invoice_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_number  VARCHAR(30) NOT NULL,
    order_id        BIGINT NOT NULL REFERENCES orders.order_master(order_id),
    customer_id     INT REFERENCES crm.customer_master(customer_id),
    discount_id     INT REFERENCES billing.discount_master(discount_id),
    sub_total       NUMERIC(12,2) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    tax_amount      NUMERIC(12,2) NOT NULL DEFAULT 0,
    round_off       NUMERIC(12,2) NOT NULL DEFAULT 0,
    grand_total     NUMERIC(12,2) NOT NULL DEFAULT 0,
    paid_amount     NUMERIC(12,2) NOT NULL DEFAULT 0,
    payment_status  VARCHAR(20) NOT NULL DEFAULT 'Unpaid',
    invoice_date    TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      INT REFERENCES admin.user_master(user_id),
    CONSTRAINT uq_invoice_number UNIQUE (invoice_number),
    CONSTRAINT ck_invoice_payment_status CHECK (payment_status IN ('Unpaid','Partial','Paid','Refunded'))
);
CREATE INDEX IF NOT EXISTS ix_invoice_master_date ON billing.invoice_master (invoice_date);

CREATE TABLE IF NOT EXISTS billing.invoice_items
(
    invoice_item_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_id      BIGINT NOT NULL REFERENCES billing.invoice_master(invoice_id) ON DELETE CASCADE,
    food_item_id    INT REFERENCES menu.food_item_master(food_item_id),
    item_name       VARCHAR(150) NOT NULL,
    quantity        INT NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(12,2) NOT NULL,
    tax_percentage  NUMERIC(5,2) NOT NULL DEFAULT 0,
    tax_amount      NUMERIC(12,2) NOT NULL DEFAULT 0,
    line_total      NUMERIC(12,2) NOT NULL
);

-- Payments
CREATE TABLE IF NOT EXISTS payments.payment_transactions
(
    payment_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_id      BIGINT NOT NULL REFERENCES billing.invoice_master(invoice_id),
    payment_mode_id INT NOT NULL REFERENCES payments.payment_mode_master(payment_mode_id),
    amount          NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    reference_no    VARCHAR(100),
    status          VARCHAR(20) NOT NULL DEFAULT 'Success',
    paid_on         TIMESTAMPTZ NOT NULL DEFAULT now(),
    received_by     INT REFERENCES admin.user_master(user_id),
    CONSTRAINT ck_payment_status CHECK (status IN ('Success','Pending','Failed'))
);
CREATE INDEX IF NOT EXISTS ix_payment_transactions_invoice ON payments.payment_transactions (invoice_id);

CREATE TABLE IF NOT EXISTS payments.refund_master
(
    refund_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_id  BIGINT NOT NULL REFERENCES payments.payment_transactions(payment_id),
    amount      NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    reason      VARCHAR(300),
    refunded_by INT REFERENCES admin.user_master(user_id),
    refunded_on TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Inventory
CREATE TABLE IF NOT EXISTS inventory.recipe_master
(
    recipe_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    food_item_id INT NOT NULL REFERENCES menu.food_item_master(food_item_id) ON DELETE CASCADE,
    notes        VARCHAR(300),
    created_on   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_recipe_food_item UNIQUE (food_item_id)
);

CREATE TABLE IF NOT EXISTS inventory.recipe_items
(
    recipe_item_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    recipe_id      INT NOT NULL REFERENCES inventory.recipe_master(recipe_id) ON DELETE CASCADE,
    ingredient_id  INT NOT NULL REFERENCES inventory.ingredient_master(ingredient_id),
    quantity       NUMERIC(12,3) NOT NULL CHECK (quantity > 0),
    CONSTRAINT uq_recipe_item UNIQUE (recipe_id, ingredient_id)
);

CREATE TABLE IF NOT EXISTS inventory.stock_master
(
    ingredient_id    INT NOT NULL REFERENCES inventory.ingredient_master(ingredient_id),
    branch_id        INT NOT NULL REFERENCES admin.branch_master(branch_id),
    quantity_on_hand NUMERIC(14,3) NOT NULL DEFAULT 0,
    updated_on       TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (ingredient_id, branch_id)
);

CREATE TABLE IF NOT EXISTS inventory.stock_transactions
(
    txn_id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ingredient_id  INT NOT NULL REFERENCES inventory.ingredient_master(ingredient_id),
    branch_id      INT NOT NULL REFERENCES admin.branch_master(branch_id),
    txn_type       VARCHAR(20) NOT NULL,
    quantity       NUMERIC(14,3) NOT NULL,          -- positive = stock in, negative = stock out
    reference_type VARCHAR(30),
    reference_id   BIGINT,
    remarks        VARCHAR(300),
    txn_date       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_stock_txn_type CHECK (txn_type IN ('Purchase','Consumption','Adjustment','Wastage','Return'))
);
CREATE INDEX IF NOT EXISTS ix_stock_transactions_ing ON inventory.stock_transactions (ingredient_id, txn_date);

CREATE TABLE IF NOT EXISTS inventory.stock_adjustments
(
    adjustment_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ingredient_id   INT NOT NULL REFERENCES inventory.ingredient_master(ingredient_id),
    branch_id       INT NOT NULL REFERENCES admin.branch_master(branch_id),
    adjustment_type VARCHAR(20) NOT NULL,
    quantity        NUMERIC(14,3) NOT NULL CHECK (quantity > 0),
    reason          VARCHAR(300),
    adjusted_by     INT REFERENCES admin.user_master(user_id),
    adjusted_on     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_stock_adj_type CHECK (adjustment_type IN ('Increase','Decrease','Wastage'))
);

-- Purchase
CREATE TABLE IF NOT EXISTS purchase.purchase_order
(
    po_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    po_number     VARCHAR(30) NOT NULL,
    supplier_id   INT NOT NULL REFERENCES purchase.supplier_master(supplier_id),
    branch_id     INT REFERENCES admin.branch_master(branch_id),
    order_date    DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_date DATE,
    status        VARCHAR(20) NOT NULL DEFAULT 'Draft',
    total_amount  NUMERIC(12,2) NOT NULL DEFAULT 0,
    notes         VARCHAR(300),
    created_by    INT REFERENCES admin.user_master(user_id),
    created_on    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_purchase_order_number UNIQUE (po_number),
    CONSTRAINT ck_purchase_order_status CHECK (status IN ('Draft','Ordered','Received','Cancelled'))
);

CREATE TABLE IF NOT EXISTS purchase.purchase_order_items
(
    po_item_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    po_id         INT NOT NULL REFERENCES purchase.purchase_order(po_id) ON DELETE CASCADE,
    ingredient_id INT NOT NULL REFERENCES inventory.ingredient_master(ingredient_id),
    quantity      NUMERIC(14,3) NOT NULL CHECK (quantity > 0),
    unit_price    NUMERIC(12,2) NOT NULL DEFAULT 0,
    line_total    NUMERIC(12,2) NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS purchase.purchase_invoice
(
    purchase_invoice_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_no          VARCHAR(50) NOT NULL,
    po_id               INT REFERENCES purchase.purchase_order(po_id),
    supplier_id         INT NOT NULL REFERENCES purchase.supplier_master(supplier_id),
    invoice_date        DATE NOT NULL DEFAULT CURRENT_DATE,
    sub_total           NUMERIC(12,2) NOT NULL DEFAULT 0,
    tax_amount          NUMERIC(12,2) NOT NULL DEFAULT 0,
    total_amount        NUMERIC(12,2) NOT NULL DEFAULT 0,
    paid_amount         NUMERIC(12,2) NOT NULL DEFAULT 0,
    status              VARCHAR(20) NOT NULL DEFAULT 'Unpaid',
    created_on          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_purchase_invoice UNIQUE (supplier_id, invoice_no),
    CONSTRAINT ck_purchase_invoice_status CHECK (status IN ('Unpaid','Partial','Paid'))
);

CREATE TABLE IF NOT EXISTS purchase.supplier_payment
(
    supplier_payment_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_id         INT NOT NULL REFERENCES purchase.supplier_master(supplier_id),
    purchase_invoice_id INT REFERENCES purchase.purchase_invoice(purchase_invoice_id),
    payment_mode_id     INT NOT NULL REFERENCES payments.payment_mode_master(payment_mode_id),
    amount              NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    reference_no        VARCHAR(100),
    paid_on             TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- HR attendance
CREATE TABLE IF NOT EXISTS hr.attendance
(
    attendance_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id     INT NOT NULL REFERENCES hr.employee_master(employee_id),
    attendance_date DATE NOT NULL DEFAULT CURRENT_DATE,
    check_in        TIME,
    check_out       TIME,
    status          VARCHAR(20) NOT NULL DEFAULT 'Present',
    remarks         VARCHAR(200),
    CONSTRAINT uq_attendance UNIQUE (employee_id, attendance_date),
    CONSTRAINT ck_attendance_status CHECK (status IN ('Present','Absent','Half Day','Leave'))
);

-- Expenses
CREATE TABLE IF NOT EXISTS expense.expense_voucher
(
    voucher_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    voucher_no          VARCHAR(30) NOT NULL,
    expense_category_id INT NOT NULL REFERENCES expense.expense_category_master(expense_category_id),
    branch_id           INT REFERENCES admin.branch_master(branch_id),
    expense_date        DATE NOT NULL DEFAULT CURRENT_DATE,
    amount              NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    paid_to             VARCHAR(150),
    payment_mode_id     INT REFERENCES payments.payment_mode_master(payment_mode_id),
    remarks             VARCHAR(300),
    created_by          INT REFERENCES admin.user_master(user_id),
    created_on          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_expense_voucher_no UNIQUE (voucher_no)
);

-- Customer feedback
CREATE TABLE IF NOT EXISTS crm.customer_feedback
(
    feedback_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INT REFERENCES crm.customer_master(customer_id),
    order_id    BIGINT REFERENCES orders.order_master(order_id),
    rating      INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comments    VARCHAR(500),
    created_on  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. REPORTING VIEWS -----------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_daily_sales AS
SELECT invoice_date::date AS sales_date,
       COUNT(*)           AS invoice_count,
       SUM(sub_total)     AS sub_total,
       SUM(discount_amount) AS discount_amount,
       SUM(tax_amount)    AS tax_amount,
       SUM(grand_total)   AS grand_total
FROM billing.invoice_master
GROUP BY invoice_date::date;

CREATE OR REPLACE VIEW reports.vw_item_wise_sales AS
SELECT i.food_item_id, i.item_name,
       SUM(i.quantity)   AS quantity_sold,
       SUM(i.line_total) AS sales_amount
FROM billing.invoice_items i
GROUP BY i.food_item_id, i.item_name;

CREATE OR REPLACE VIEW reports.vw_stock_status AS
SELECT g.ingredient_id, g.ingredient_name, u.short_name AS unit,
       COALESCE(SUM(s.quantity_on_hand), 0) AS quantity_on_hand,
       g.reorder_level,
       (COALESCE(SUM(s.quantity_on_hand), 0) <= g.reorder_level) AS is_low_stock
FROM inventory.ingredient_master g
JOIN inventory.unit_master u ON u.unit_id = g.unit_id
LEFT JOIN inventory.stock_master s ON s.ingredient_id = g.ingredient_id
GROUP BY g.ingredient_id, g.ingredient_name, u.short_name, g.reorder_level;

-- 6. STARTER DATA (safe to edit / delete from the application) -----------
INSERT INTO admin.role_master (role_name, description) VALUES
    ('Admin',   'Full access'),
    ('Manager', 'Manages all masters and reports'),
    ('Cashier', 'Billing and payments'),
    ('Waiter',  'Takes orders at tables'),
    ('Chef',    'Kitchen display')
ON CONFLICT DO NOTHING;

INSERT INTO admin.branch_master (branch_name, branch_code) VALUES ('Main Branch', 'MB01')
ON CONFLICT DO NOTHING;

INSERT INTO admin.user_master (user_name, full_name, password_hash, role_id, branch_id)
SELECT 'admin', 'Administrator', '100000.EBESExQVFhcYGRobHB0eHw==.aOBUuq2XYhNhspft3DFF6G4hQcvMl2WtLkVmkl9IFCs=', r.role_id, b.branch_id
FROM admin.role_master r, admin.branch_master b
WHERE r.role_name = 'Admin' AND b.branch_code = 'MB01'
ON CONFLICT DO NOTHING;

INSERT INTO orders.floor_master (floor_name, branch_id, description)
SELECT v.n, b.branch_id, v.d
FROM (VALUES ('Ground Floor','Main dining hall'), ('AC Hall','Air-conditioned section'), ('Rooftop','Open-air seating')) AS v(n, d),
     admin.branch_master b
WHERE b.branch_code = 'MB01'
ON CONFLICT DO NOTHING;

INSERT INTO orders.table_master (floor_id, table_number, capacity)
SELECT f.floor_id, v.t, v.c
FROM (VALUES
    ('Ground Floor','G1',4),('Ground Floor','G2',4),('Ground Floor','G3',4),('Ground Floor','G4',6),('Ground Floor','G5',6),('Ground Floor','G6',2),
    ('AC Hall','A1',4),('AC Hall','A2',4),('AC Hall','A3',6),('AC Hall','A4',8),
    ('Rooftop','R1',2),('Rooftop','R2',4),('Rooftop','R3',4)
) AS v(fl, t, c)
JOIN orders.floor_master f ON f.floor_name = v.fl
ON CONFLICT DO NOTHING;

INSERT INTO orders.kitchen_station (station_name, description) VALUES
    ('Main Kitchen', 'Curries, rice and gravies'),
    ('Tandoor',      'Tandoor and grill items'),
    ('Chinese',      'Indo-Chinese counter'),
    ('Beverage Bar', 'Juices, shakes, tea and coffee'),
    ('Dessert',      'Sweets and ice creams')
ON CONFLICT DO NOTHING;

INSERT INTO menu.category_master (category_name, description, display_order) VALUES
    ('Starters',    'Appetizers and snacks', 1),
    ('Main Course', 'Curries and gravies', 2),
    ('Biryani & Rice', 'Biryani, pulao and rice', 3),
    ('Breads',      'Rotis, naans and parathas', 4),
    ('Beverages',   'Hot and cold drinks', 5),
    ('Desserts',    'Sweet endings', 6)
ON CONFLICT DO NOTHING;

INSERT INTO billing.tax_master (tax_name, tax_percentage, is_inclusive) VALUES
    ('No Tax',  0,  FALSE),
    ('GST 5%',  5,  FALSE),
    ('GST 12%', 12, FALSE),
    ('GST 18%', 18, FALSE)
ON CONFLICT DO NOTHING;

INSERT INTO menu.food_item_master (item_code, food_name, category_id, food_type, price, tax_id, kitchen_station_id, preparation_time)
SELECT v.code, v.nm, c.category_id, v.ft, v.pr, t.tax_id, k.kitchen_station_id, v.pt
FROM (VALUES
    ('FI001','Paneer Tikka','Starters','Veg',220,'GST 5%','Tandoor',15),
    ('FI002','Chicken 65','Starters','Non-Veg',240,'GST 5%','Main Kitchen',15),
    ('FI003','Veg Spring Roll','Starters','Veg',160,'GST 5%','Chinese',12),
    ('FI004','Paneer Butter Masala','Main Course','Veg',260,'GST 5%','Main Kitchen',18),
    ('FI005','Butter Chicken','Main Course','Non-Veg',310,'GST 5%','Main Kitchen',20),
    ('FI006','Dal Tadka','Main Course','Veg',180,'GST 5%','Main Kitchen',12),
    ('FI007','Veg Biryani','Biryani & Rice','Veg',210,'GST 5%','Main Kitchen',25),
    ('FI008','Chicken Biryani','Biryani & Rice','Non-Veg',280,'GST 5%','Main Kitchen',25),
    ('FI009','Butter Naan','Breads','Veg',45,'GST 5%','Tandoor',8),
    ('FI010','Tandoori Roti','Breads','Veg',25,'GST 5%','Tandoor',6),
    ('FI011','Masala Chai','Beverages','Beverage',30,'GST 5%','Beverage Bar',5),
    ('FI012','Fresh Lime Soda','Beverages','Beverage',60,'GST 5%','Beverage Bar',5),
    ('FI013','Gulab Jamun','Desserts','Veg',70,'GST 5%','Dessert',5),
    ('FI014','Vanilla Ice Cream','Desserts','Veg',80,'GST 5%','Dessert',3)
) AS v(code, nm, cat, ft, pr, tx, st, pt)
JOIN menu.category_master c ON c.category_name = v.cat
LEFT JOIN billing.tax_master t ON t.tax_name = v.tx
LEFT JOIN orders.kitchen_station k ON k.station_name = v.st
ON CONFLICT DO NOTHING;

INSERT INTO menu.addon_master (addon_name, price) VALUES
    ('Extra Cheese', 30), ('Extra Gravy', 25), ('Raita', 30), ('Boiled Egg', 15)
ON CONFLICT DO NOTHING;

INSERT INTO hr.designation_master (designation_name, description) VALUES
    ('Manager', 'Restaurant manager'), ('Captain', 'Floor captain'), ('Waiter', 'Serves tables'),
    ('Cashier', 'Billing counter'), ('Head Chef', 'Kitchen head'), ('Cook', 'Kitchen staff'),
    ('Helper', 'Kitchen / cleaning helper')
ON CONFLICT DO NOTHING;

INSERT INTO hr.shift_master (shift_name, start_time, end_time) VALUES
    ('Morning', '06:00', '14:00'), ('Afternoon', '12:00', '20:00'), ('Evening', '16:00', '23:59')
ON CONFLICT DO NOTHING;

INSERT INTO hr.employee_master (employee_code, full_name, designation_id, shift_id, branch_id, joining_date)
SELECT v.code, v.nm, d.designation_id, s.shift_id, b.branch_id, CURRENT_DATE
FROM (VALUES
    ('EMP001','Sample Manager','Manager','Morning'),
    ('EMP002','Sample Waiter','Waiter','Afternoon'),
    ('EMP003','Sample Chef','Head Chef','Morning')
) AS v(code, nm, des, sh)
JOIN hr.designation_master d ON d.designation_name = v.des
JOIN hr.shift_master s ON s.shift_name = v.sh
CROSS JOIN admin.branch_master b
WHERE b.branch_code = 'MB01'
ON CONFLICT DO NOTHING;

INSERT INTO inventory.unit_master (unit_name, short_name) VALUES
    ('Kilogram','kg'), ('Gram','g'), ('Litre','l'), ('Millilitre','ml'), ('Piece','pcs'), ('Dozen','doz'), ('Packet','pkt')
ON CONFLICT DO NOTHING;

INSERT INTO inventory.ingredient_master (ingredient_name, unit_id, reorder_level, cost_per_unit)
SELECT v.nm, u.unit_id, v.rl, v.cp
FROM (VALUES
    ('Basmati Rice','kg',20,110), ('Paneer','kg',5,320), ('Chicken','kg',10,220),
    ('Cooking Oil','l',15,140), ('Onion','kg',20,35), ('Tomato','kg',15,40), ('Milk','l',10,60)
) AS v(nm, un, rl, cp)
JOIN inventory.unit_master u ON u.short_name = v.un
ON CONFLICT DO NOTHING;

INSERT INTO billing.discount_master (discount_name, discount_code, discount_type, discount_value, min_order_amount) VALUES
    ('Welcome 10%', 'WELCOME10', 'Percentage', 10, 500),
    ('Flat 100 Off', 'FLAT100',   'Flat',       100, 1000)
ON CONFLICT DO NOTHING;

INSERT INTO payments.payment_mode_master (mode_name, mode_type, requires_reference) VALUES
    ('Cash', 'Cash', FALSE), ('UPI', 'UPI', TRUE), ('Debit / Credit Card', 'Card', TRUE), ('Online Gateway', 'Online', TRUE)
ON CONFLICT DO NOTHING;

INSERT INTO expense.expense_category_master (expense_category_name, description) VALUES
    ('Rent', 'Shop / building rent'), ('Electricity', 'Power bills'), ('Gas & Fuel', 'LPG, firewood, etc.'),
    ('Salaries', 'Staff salaries'), ('Maintenance', 'Repairs and upkeep'), ('Marketing', 'Ads and promotions'),
    ('Miscellaneous', 'Other daily expenses')
ON CONFLICT DO NOTHING;

/* =====================================================================
   RESTAURANT MANAGEMENT - PHASE 2 UPDATE (PostgreSQL)
   Run AFTER RestaurantDB.sql, in the same database (RestaurantDB).
   Safe to run more than once.

   Adds
     1. Schema pos: orders, order items, payments, table queue, UPI settings
        (used by the new Tables & Orders / Kitchen / Waiter / Billing screens)
     2. Indian + South Indian menu: 430 items in 18 categories, with
        GST 5% and the right kitchen station from your starter data.
        Prices are SAMPLE prices in INR - edit them under Food Items.
   Does NOT touch your existing tables or data.
   ===================================================================== */
BEGIN;

-- 1. OPERATIONS TABLES --------------------------------------------------
CREATE SCHEMA IF NOT EXISTS pos;

CREATE SEQUENCE IF NOT EXISTS pos.order_no_seq START 1001;

CREATE TABLE IF NOT EXISTS pos.restaurant_setting (
    restaurant_setting_id  int PRIMARY KEY,
    restaurant_name        varchar(150) NOT NULL DEFAULT 'My Restaurant',
    owner_name             varchar(100),
    owner_mobile           varchar(15),
    upi_id                 varchar(100),
    upi_payee_name         varchar(100),
    public_base_url        varchar(200),
    bill_footer            varchar(300) DEFAULT 'Thank you! Visit again.',
    updated_on             timestamptz NOT NULL DEFAULT now()
);
INSERT INTO pos.restaurant_setting (restaurant_setting_id) VALUES (1) ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS pos.customer_order (
    order_id          serial PRIMARY KEY,
    order_no          varchar(30)  NOT NULL UNIQUE,
    order_type        varchar(20)  NOT NULL DEFAULT 'DineIn',      -- DineIn | Parcel
    dining_table_id   int REFERENCES orders.table_master(dining_table_id),
    guests            int NOT NULL DEFAULT 1,
    customer_id       int REFERENCES crm.customer_master(customer_id),
    customer_name     varchar(100),
    customer_mobile   varchar(15),
    status            varchar(20)  NOT NULL DEFAULT 'Open',        -- Open | Paid | Cancelled
    sub_total         numeric(12,2) NOT NULL DEFAULT 0,
    tax_amount        numeric(12,2) NOT NULL DEFAULT 0,
    discount_amount   numeric(12,2) NOT NULL DEFAULT 0,
    round_off         numeric(12,2) NOT NULL DEFAULT 0,
    grand_total       numeric(12,2) NOT NULL DEFAULT 0,
    paid_amount       numeric(12,2) NOT NULL DEFAULT 0,
    pay_token         uuid NOT NULL DEFAULT gen_random_uuid(),
    customer_utr      varchar(40),
    notes             varchar(300),
    created_by        varchar(100),
    created_on        timestamptz NOT NULL DEFAULT now(),
    paid_on           timestamptz
);
CREATE INDEX IF NOT EXISTS ix_customer_order_status ON pos.customer_order(status);
CREATE INDEX IF NOT EXISTS ix_customer_order_table  ON pos.customer_order(dining_table_id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_customer_order_token ON pos.customer_order(pay_token);

CREATE TABLE IF NOT EXISTS pos.order_item (
    order_item_id       serial PRIMARY KEY,
    order_id            int NOT NULL REFERENCES pos.customer_order(order_id) ON DELETE CASCADE,
    food_item_id        int REFERENCES menu.food_item_master(food_item_id),
    item_name           varchar(150) NOT NULL,
    food_type           varchar(30),
    quantity            int NOT NULL DEFAULT 1,
    unit_price          numeric(12,2) NOT NULL DEFAULT 0,
    tax_percent         numeric(12,2) NOT NULL DEFAULT 0,
    tax_inclusive       boolean NOT NULL DEFAULT false,
    line_base           numeric(12,2) NOT NULL DEFAULT 0,
    tax_amount          numeric(12,2) NOT NULL DEFAULT 0,
    line_total          numeric(12,2) NOT NULL DEFAULT 0,
    note                varchar(200),
    kitchen_station_id  int,
    round_no            int NOT NULL DEFAULT 1,
    status              varchar(20) NOT NULL DEFAULT 'New',        -- New | Preparing | Ready | Served | Cancelled
    created_on          timestamptz NOT NULL DEFAULT now(),
    started_on          timestamptz,
    ready_on            timestamptz,
    served_on           timestamptz
);
CREATE INDEX IF NOT EXISTS ix_order_item_status ON pos.order_item(status);
CREATE INDEX IF NOT EXISTS ix_order_item_order  ON pos.order_item(order_id);

CREATE TABLE IF NOT EXISTS pos.order_payment (
    order_payment_id  serial PRIMARY KEY,
    order_id          int NOT NULL REFERENCES pos.customer_order(order_id) ON DELETE CASCADE,
    mode_name         varchar(50) NOT NULL,
    amount            numeric(12,2) NOT NULL,
    reference_no      varchar(60),
    received_by       varchar(100),
    created_on        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pos.table_waiting (
    table_waiting_id   serial PRIMARY KEY,
    customer_name      varchar(100) NOT NULL,
    mobile             varchar(15),
    party_size         int NOT NULL DEFAULT 2,
    status             varchar(20) NOT NULL DEFAULT 'Waiting',      -- Waiting | Seated | Cancelled
    assigned_table_id  int,
    created_on         timestamptz NOT NULL DEFAULT now(),
    seated_on          timestamptz
);


-- 2. MENU CATEGORIES ----------------------------------------------------
INSERT INTO menu.category_master (category_name, description, display_order)
SELECT v.n, v.d, v.o FROM (VALUES
  ('Tiffin & Breakfast', 'South Indian tiffin items', 1),
  ('Dosa Varieties', 'Dosas and similar crepes', 2),
  ('Rice Varieties', 'Variety rice and plain rice', 3),
  ('Meals & Thali', 'Full meals served South Indian style', 4),
  ('Biryani & Pulao', 'Biryanis from across India', 5),
  ('Veg Curries & Dal', 'Gravies, kuzhambu, kootu and dal', 6),
  ('Non-Veg Curries', 'Chicken, mutton, egg and beef gravies', 7),
  ('Seafood', 'Fish, prawn and crab dishes', 8),
  ('Starters - Veg', 'Veg appetisers', 9),
  ('Starters - Non-Veg', 'Chicken, mutton, egg and fish appetisers', 10),
  ('Breads & Parotta', 'Parotta, rotis, naan and paratha', 11),
  ('Indo-Chinese', 'Chinese-style street and restaurant favourites', 12),
  ('Chaats & Snacks', 'Street food and evening snacks', 13),
  ('Soups, Rasam & Sides', 'Soups, accompaniments and extras', 14),
  ('Desserts & Sweets', 'Indian sweets and desserts', 15),
  ('Hot Beverages', 'Coffee, tea and hot drinks', 16),
  ('Cold Beverages & Juices', 'Juices, shakes and coolers', 17),
  ('Regional Favourites (Pan-India)', 'Popular dishes from other Indian regions', 18)
) AS v(n, d, o)
WHERE NOT EXISTS (SELECT 1 FROM menu.category_master c WHERE c.category_name = v.n);

-- 3. MENU ITEMS (skips any dish already present in the same category) ----
INSERT INTO menu.food_item_master
       (item_code, food_name, category_id, food_type, price, tax_id, kitchen_station_id, preparation_time)
SELECT v.code, v.nm, c.category_id, v.ft, v.pr, t.tax_id, k.kitchen_station_id, v.pt
FROM (VALUES
  ('SI0001', 'Idli (2 pcs)', 'Tiffin & Breakfast', 'Veg', 40::numeric, 'Main Kitchen', 10::int),
  ('SI0002', 'Mini Idli Sambar', 'Tiffin & Breakfast', 'Veg', 60::numeric, 'Main Kitchen', 10::int),
  ('SI0003', 'Ghee Podi Idli', 'Tiffin & Breakfast', 'Veg', 70::numeric, 'Main Kitchen', 12::int),
  ('SI0004', 'Thatte Idli', 'Tiffin & Breakfast', 'Veg', 60::numeric, 'Main Kitchen', 10::int),
  ('SI0005', 'Rava Idli (2 pcs)', 'Tiffin & Breakfast', 'Veg', 60::numeric, 'Main Kitchen', 12::int),
  ('SI0006', 'Kanchipuram Idli', 'Tiffin & Breakfast', 'Veg', 70::numeric, 'Main Kitchen', 12::int),
  ('SI0007', 'Medu Vada (2 pcs)', 'Tiffin & Breakfast', 'Veg', 50::numeric, 'Main Kitchen', 10::int),
  ('SI0008', 'Sambar Vada', 'Tiffin & Breakfast', 'Veg', 70::numeric, 'Main Kitchen', 10::int),
  ('SI0009', 'Rasam Vada', 'Tiffin & Breakfast', 'Veg', 70::numeric, 'Main Kitchen', 10::int),
  ('SI0010', 'Curd Vada', 'Tiffin & Breakfast', 'Veg', 70::numeric, 'Main Kitchen', 10::int),
  ('SI0011', 'Masala Vada (3 pcs)', 'Tiffin & Breakfast', 'Veg', 40::numeric, 'Main Kitchen', 10::int),
  ('SI0012', 'Idli Vada Combo', 'Tiffin & Breakfast', 'Veg', 70::numeric, 'Main Kitchen', 10::int),
  ('SI0013', 'Upma', 'Tiffin & Breakfast', 'Veg', 45::numeric, 'Main Kitchen', 10::int),
  ('SI0014', 'Rava Kesari', 'Tiffin & Breakfast', 'Veg', 45::numeric, 'Main Kitchen', 8::int),
  ('SI0015', 'Khara Bath', 'Tiffin & Breakfast', 'Veg', 50::numeric, 'Main Kitchen', 10::int),
  ('SI0016', 'Ven Pongal', 'Tiffin & Breakfast', 'Veg', 55::numeric, 'Main Kitchen', 10::int),
  ('SI0017', 'Sakkarai Pongal', 'Tiffin & Breakfast', 'Veg', 60::numeric, 'Main Kitchen', 10::int),
  ('SI0018', 'Poori Masala (2 pcs)', 'Tiffin & Breakfast', 'Veg', 60::numeric, 'Main Kitchen', 12::int),
  ('SI0019', 'Chapati Kurma', 'Tiffin & Breakfast', 'Veg', 60::numeric, 'Main Kitchen', 12::int),
  ('SI0020', 'Uttapam Plain', 'Tiffin & Breakfast', 'Veg', 70::numeric, 'Main Kitchen', 12::int),
  ('SI0021', 'Onion Uttapam', 'Tiffin & Breakfast', 'Veg', 80::numeric, 'Main Kitchen', 12::int),
  ('SI0022', 'Tomato Uttapam', 'Tiffin & Breakfast', 'Veg', 80::numeric, 'Main Kitchen', 12::int),
  ('SI0023', 'Podi Uttapam', 'Tiffin & Breakfast', 'Veg', 80::numeric, 'Main Kitchen', 12::int),
  ('SI0024', 'Appam with Veg Stew', 'Tiffin & Breakfast', 'Veg', 90::numeric, 'Main Kitchen', 15::int),
  ('SI0025', 'Idiyappam with Coconut Milk', 'Tiffin & Breakfast', 'Veg', 80::numeric, 'Main Kitchen', 15::int),
  ('SI0026', 'Puttu with Kadala Curry', 'Tiffin & Breakfast', 'Veg', 90::numeric, 'Main Kitchen', 15::int),
  ('SI0027', 'Pesarattu', 'Tiffin & Breakfast', 'Veg', 70::numeric, 'Main Kitchen', 12::int),
  ('SI0028', 'Akki Roti', 'Tiffin & Breakfast', 'Veg', 60::numeric, 'Main Kitchen', 12::int),
  ('SI0029', 'Ragi Mudde with Saaru', 'Tiffin & Breakfast', 'Veg', 80::numeric, 'Main Kitchen', 15::int),
  ('SI0030', 'Mysore Bonda (4 pcs)', 'Tiffin & Breakfast', 'Veg', 50::numeric, 'Main Kitchen', 10::int),
  ('SI0031', 'Mirchi Bajji (3 pcs)', 'Tiffin & Breakfast', 'Veg', 40::numeric, 'Main Kitchen', 10::int),
  ('SI0032', 'Kuzhi Paniyaram (6 pcs)', 'Tiffin & Breakfast', 'Veg', 60::numeric, 'Main Kitchen', 12::int),
  ('SI0033', 'Bisi Bele Bath', 'Tiffin & Breakfast', 'Veg', 90::numeric, 'Main Kitchen', 12::int),
  ('SI0034', 'Sabudana Khichdi', 'Tiffin & Breakfast', 'Veg', 70::numeric, 'Main Kitchen', 10::int),
  ('SI0035', 'Plain Dosa', 'Dosa Varieties', 'Veg', 60::numeric, 'Main Kitchen', 10::int),
  ('SI0036', 'Masala Dosa', 'Dosa Varieties', 'Veg', 80::numeric, 'Main Kitchen', 12::int),
  ('SI0037', 'Ghee Roast Dosa', 'Dosa Varieties', 'Veg', 90::numeric, 'Main Kitchen', 12::int),
  ('SI0038', 'Mysore Masala Dosa', 'Dosa Varieties', 'Veg', 100::numeric, 'Main Kitchen', 12::int),
  ('SI0039', 'Rava Dosa', 'Dosa Varieties', 'Veg', 90::numeric, 'Main Kitchen', 12::int),
  ('SI0040', 'Onion Rava Dosa', 'Dosa Varieties', 'Veg', 100::numeric, 'Main Kitchen', 12::int),
  ('SI0041', 'Rava Masala Dosa', 'Dosa Varieties', 'Veg', 110::numeric, 'Main Kitchen', 14::int),
  ('SI0042', 'Set Dosa (3 pcs)', 'Dosa Varieties', 'Veg', 80::numeric, 'Main Kitchen', 10::int),
  ('SI0043', 'Neer Dosa (3 pcs)', 'Dosa Varieties', 'Veg', 70::numeric, 'Main Kitchen', 10::int),
  ('SI0044', 'Benne Dosa', 'Dosa Varieties', 'Veg', 90::numeric, 'Main Kitchen', 12::int),
  ('SI0045', 'Paper Dosa', 'Dosa Varieties', 'Veg', 100::numeric, 'Main Kitchen', 12::int),
  ('SI0046', 'Paneer Dosa', 'Dosa Varieties', 'Veg', 120::numeric, 'Main Kitchen', 14::int),
  ('SI0047', 'Cheese Dosa', 'Dosa Varieties', 'Veg', 110::numeric, 'Main Kitchen', 12::int),
  ('SI0048', 'Podi Dosa', 'Dosa Varieties', 'Veg', 80::numeric, 'Main Kitchen', 10::int),
  ('SI0049', 'Egg Dosa', 'Dosa Varieties', 'Egg', 90::numeric, 'Main Kitchen', 12::int),
  ('SI0050', 'Chicken Keema Dosa', 'Dosa Varieties', 'Non-Veg', 130::numeric, 'Main Kitchen', 15::int),
  ('SI0051', 'Adai', 'Dosa Varieties', 'Veg', 80::numeric, 'Main Kitchen', 12::int),
  ('SI0052', 'Adai Avial', 'Dosa Varieties', 'Veg', 100::numeric, 'Main Kitchen', 14::int),
  ('SI0053', 'Ragi Dosa', 'Dosa Varieties', 'Veg', 80::numeric, 'Main Kitchen', 12::int),
  ('SI0054', 'Onion Dosa', 'Dosa Varieties', 'Veg', 80::numeric, 'Main Kitchen', 10::int),
  ('SI0055', 'Kal Dosa (2 pcs)', 'Dosa Varieties', 'Veg', 70::numeric, 'Main Kitchen', 10::int),
  ('SI0056', 'Cone Dosa', 'Dosa Varieties', 'Veg', 90::numeric, 'Main Kitchen', 12::int),
  ('SI0057', 'Pizza Dosa', 'Dosa Varieties', 'Veg', 120::numeric, 'Main Kitchen', 14::int),
  ('SI0058', 'Family Dosa', 'Dosa Varieties', 'Veg', 220::numeric, 'Main Kitchen', 18::int),
  ('SI0059', 'Spring Dosa', 'Dosa Varieties', 'Veg', 110::numeric, 'Main Kitchen', 14::int),
  ('SI0060', 'Curd Rice', 'Rice Varieties', 'Veg', 70::numeric, 'Main Kitchen', 5::int),
  ('SI0061', 'Lemon Rice', 'Rice Varieties', 'Veg', 70::numeric, 'Main Kitchen', 8::int),
  ('SI0062', 'Tamarind Rice (Puliyodarai)', 'Rice Varieties', 'Veg', 70::numeric, 'Main Kitchen', 8::int),
  ('SI0063', 'Tomato Rice', 'Rice Varieties', 'Veg', 70::numeric, 'Main Kitchen', 8::int),
  ('SI0064', 'Coconut Rice', 'Rice Varieties', 'Veg', 75::numeric, 'Main Kitchen', 8::int),
  ('SI0065', 'Vangi Bath', 'Rice Varieties', 'Veg', 80::numeric, 'Main Kitchen', 10::int),
  ('SI0066', 'Sambar Rice', 'Rice Varieties', 'Veg', 80::numeric, 'Main Kitchen', 8::int),
  ('SI0067', 'Rasam Rice', 'Rice Varieties', 'Veg', 75::numeric, 'Main Kitchen', 8::int),
  ('SI0068', 'Ghee Rice', 'Rice Varieties', 'Veg', 90::numeric, 'Main Kitchen', 10::int),
  ('SI0069', 'Jeera Rice', 'Rice Varieties', 'Veg', 80::numeric, 'Main Kitchen', 10::int),
  ('SI0070', 'Steamed Rice', 'Rice Varieties', 'Veg', 40::numeric, 'Main Kitchen', 5::int),
  ('SI0071', 'Kerala Matta Rice', 'Rice Varieties', 'Veg', 50::numeric, 'Main Kitchen', 5::int),
  ('SI0072', 'Gongura Rice', 'Rice Varieties', 'Veg', 90::numeric, 'Main Kitchen', 10::int),
  ('SI0073', 'Mango Rice', 'Rice Varieties', 'Veg', 75::numeric, 'Main Kitchen', 8::int),
  ('SI0074', 'Pudina Rice', 'Rice Varieties', 'Veg', 80::numeric, 'Main Kitchen', 8::int),
  ('SI0075', 'Bagara Rice', 'Rice Varieties', 'Veg', 120::numeric, 'Main Kitchen', 12::int),
  ('SI0076', 'Kuska (Plain Biryani Rice)', 'Rice Varieties', 'Veg', 90::numeric, 'Main Kitchen', 10::int),
  ('SI0077', 'Egg Fried Rice', 'Rice Varieties', 'Egg', 140::numeric, 'Main Kitchen', 12::int),
  ('SI0078', 'South Indian Veg Meals', 'Meals & Thali', 'Veg', 150::numeric, 'Main Kitchen', 10::int),
  ('SI0079', 'Mini Meals', 'Meals & Thali', 'Veg', 110::numeric, 'Main Kitchen', 10::int),
  ('SI0080', 'Andhra Meals', 'Meals & Thali', 'Veg', 170::numeric, 'Main Kitchen', 12::int),
  ('SI0081', 'Kerala Sadya', 'Meals & Thali', 'Veg', 250::numeric, 'Main Kitchen', 15::int),
  ('SI0082', 'Karnataka Oota (Meals)', 'Meals & Thali', 'Veg', 160::numeric, 'Main Kitchen', 12::int),
  ('SI0083', 'Chettinad Meals', 'Meals & Thali', 'Veg', 200::numeric, 'Main Kitchen', 15::int),
  ('SI0084', 'Banana Leaf Meals', 'Meals & Thali', 'Veg', 180::numeric, 'Main Kitchen', 12::int),
  ('SI0085', 'Udupi Thali', 'Meals & Thali', 'Veg', 190::numeric, 'Main Kitchen', 12::int),
  ('SI0086', 'Non-Veg Meals (Chicken)', 'Meals & Thali', 'Non-Veg', 230::numeric, 'Main Kitchen', 15::int),
  ('SI0087', 'Mutton Meals', 'Meals & Thali', 'Non-Veg', 290::numeric, 'Main Kitchen', 18::int),
  ('SI0088', 'Fish Meals', 'Meals & Thali', 'Non-Veg', 250::numeric, 'Main Kitchen', 15::int),
  ('SI0089', 'Egg Meals', 'Meals & Thali', 'Egg', 190::numeric, 'Main Kitchen', 12::int),
  ('SI0090', 'Curd Rice Combo', 'Meals & Thali', 'Veg', 120::numeric, 'Main Kitchen', 8::int),
  ('SI0091', 'Kids Meal', 'Meals & Thali', 'Veg', 120::numeric, 'Main Kitchen', 10::int),
  ('SI0092', 'Hyderabadi Veg Thali', 'Meals & Thali', 'Veg', 200::numeric, 'Main Kitchen', 12::int),
  ('SI0093', 'Rajasthani Thali', 'Meals & Thali', 'Veg', 260::numeric, 'Main Kitchen', 15::int),
  ('SI0094', 'Gujarati Thali', 'Meals & Thali', 'Veg', 250::numeric, 'Main Kitchen', 15::int),
  ('SI0095', 'Bengali Veg Thali', 'Meals & Thali', 'Veg', 230::numeric, 'Main Kitchen', 15::int),
  ('SI0096', 'Hyderabadi Chicken Dum Biryani', 'Biryani & Pulao', 'Non-Veg', 260::numeric, 'Main Kitchen', 25::int),
  ('SI0097', 'Hyderabadi Mutton Biryani', 'Biryani & Pulao', 'Non-Veg', 340::numeric, 'Main Kitchen', 30::int),
  ('SI0098', 'Hyderabadi Veg Biryani', 'Biryani & Pulao', 'Veg', 200::numeric, 'Main Kitchen', 22::int),
  ('SI0099', 'Hyderabadi Egg Biryani', 'Biryani & Pulao', 'Egg', 190::numeric, 'Main Kitchen', 22::int),
  ('SI0100', 'Chicken 65 Biryani', 'Biryani & Pulao', 'Non-Veg', 280::numeric, 'Main Kitchen', 25::int),
  ('SI0101', 'Ambur Chicken Biryani', 'Biryani & Pulao', 'Non-Veg', 260::numeric, 'Main Kitchen', 25::int),
  ('SI0102', 'Dindigul Thalappakatti Mutton Biryani', 'Biryani & Pulao', 'Non-Veg', 340::numeric, 'Main Kitchen', 30::int),
  ('SI0103', 'Chettinad Chicken Biryani', 'Biryani & Pulao', 'Non-Veg', 270::numeric, 'Main Kitchen', 25::int),
  ('SI0104', 'Thalassery Chicken Biryani', 'Biryani & Pulao', 'Non-Veg', 270::numeric, 'Main Kitchen', 25::int),
  ('SI0105', 'Kerala Beef Biryani', 'Biryani & Pulao', 'Non-Veg', 300::numeric, 'Main Kitchen', 28::int),
  ('SI0106', 'Donne Biryani (Bangalore)', 'Biryani & Pulao', 'Non-Veg', 250::numeric, 'Main Kitchen', 25::int),
  ('SI0107', 'Awadhi Biryani (Lucknow)', 'Biryani & Pulao', 'Non-Veg', 280::numeric, 'Main Kitchen', 28::int),
  ('SI0108', 'Kolkata Chicken Biryani', 'Biryani & Pulao', 'Non-Veg', 260::numeric, 'Main Kitchen', 25::int),
  ('SI0109', 'Prawns Biryani', 'Biryani & Pulao', 'Non-Veg', 320::numeric, 'Main Kitchen', 28::int),
  ('SI0110', 'Fish Biryani', 'Biryani & Pulao', 'Non-Veg', 300::numeric, 'Main Kitchen', 28::int),
  ('SI0111', 'Mutton Keema Biryani', 'Biryani & Pulao', 'Non-Veg', 330::numeric, 'Main Kitchen', 28::int),
  ('SI0112', 'Paneer Biryani', 'Biryani & Pulao', 'Veg', 230::numeric, 'Main Kitchen', 22::int),
  ('SI0113', 'Mushroom Biryani', 'Biryani & Pulao', 'Veg', 210::numeric, 'Main Kitchen', 22::int),
  ('SI0114', 'Veg Pulao', 'Biryani & Pulao', 'Veg', 150::numeric, 'Main Kitchen', 15::int),
  ('SI0115', 'Kashmiri Pulao', 'Biryani & Pulao', 'Veg', 170::numeric, 'Main Kitchen', 15::int),
  ('SI0116', 'Jeera Pulao', 'Biryani & Pulao', 'Veg', 130::numeric, 'Main Kitchen', 12::int),
  ('SI0117', 'Biryani Family Pack (4 pax)', 'Biryani & Pulao', 'Non-Veg', 760::numeric, 'Main Kitchen', 35::int),
  ('SI0118', 'Sambar', 'Veg Curries & Dal', 'Veg', 60::numeric, 'Main Kitchen', 5::int),
  ('SI0119', 'Tomato Rasam', 'Veg Curries & Dal', 'Veg', 50::numeric, 'Main Kitchen', 5::int),
  ('SI0120', 'Kootu', 'Veg Curries & Dal', 'Veg', 80::numeric, 'Main Kitchen', 10::int),
  ('SI0121', 'Avial', 'Veg Curries & Dal', 'Veg', 110::numeric, 'Main Kitchen', 12::int),
  ('SI0122', 'Beans Poriyal', 'Veg Curries & Dal', 'Veg', 80::numeric, 'Main Kitchen', 10::int),
  ('SI0123', 'Kerala Veg Stew', 'Veg Curries & Dal', 'Veg', 120::numeric, 'Main Kitchen', 12::int),
  ('SI0124', 'Vegetable Kurma', 'Veg Curries & Dal', 'Veg', 110::numeric, 'Main Kitchen', 12::int),
  ('SI0125', 'Chettinad Veg Curry', 'Veg Curries & Dal', 'Veg', 130::numeric, 'Main Kitchen', 14::int),
  ('SI0126', 'Gutti Vankaya Curry', 'Veg Curries & Dal', 'Veg', 130::numeric, 'Main Kitchen', 15::int),
  ('SI0127', 'Tomato Pappu', 'Veg Curries & Dal', 'Veg', 100::numeric, 'Main Kitchen', 12::int),
  ('SI0128', 'Gongura Pappu', 'Veg Curries & Dal', 'Veg', 110::numeric, 'Main Kitchen', 12::int),
  ('SI0129', 'Dal Tadka', 'Veg Curries & Dal', 'Veg', 120::numeric, 'Main Kitchen', 12::int),
  ('SI0130', 'Dal Fry', 'Veg Curries & Dal', 'Veg', 110::numeric, 'Main Kitchen', 12::int),
  ('SI0131', 'Kerala Parippu Curry', 'Veg Curries & Dal', 'Veg', 100::numeric, 'Main Kitchen', 10::int),
  ('SI0132', 'Pulissery', 'Veg Curries & Dal', 'Veg', 90::numeric, 'Main Kitchen', 10::int),
  ('SI0133', 'Mor Kuzhambu', 'Veg Curries & Dal', 'Veg', 90::numeric, 'Main Kitchen', 10::int),
  ('SI0134', 'Vatha Kuzhambu', 'Veg Curries & Dal', 'Veg', 100::numeric, 'Main Kitchen', 12::int),
  ('SI0135', 'Kara Kuzhambu', 'Veg Curries & Dal', 'Veg', 100::numeric, 'Main Kitchen', 12::int),
  ('SI0136', 'Mirchi Ka Salan', 'Veg Curries & Dal', 'Veg', 120::numeric, 'Main Kitchen', 12::int),
  ('SI0137', 'Bagara Baingan', 'Veg Curries & Dal', 'Veg', 150::numeric, 'Main Kitchen', 14::int),
  ('SI0138', 'Paneer Butter Masala', 'Veg Curries & Dal', 'Veg', 190::numeric, 'Main Kitchen', 14::int),
  ('SI0139', 'Kadai Paneer', 'Veg Curries & Dal', 'Veg', 190::numeric, 'Main Kitchen', 14::int),
  ('SI0140', 'Palak Paneer', 'Veg Curries & Dal', 'Veg', 180::numeric, 'Main Kitchen', 14::int),
  ('SI0141', 'Paneer Tikka Masala', 'Veg Curries & Dal', 'Veg', 200::numeric, 'Main Kitchen', 15::int),
  ('SI0142', 'Malai Kofta', 'Veg Curries & Dal', 'Veg', 190::numeric, 'Main Kitchen', 15::int),
  ('SI0143', 'Mixed Veg Curry', 'Veg Curries & Dal', 'Veg', 150::numeric, 'Main Kitchen', 12::int),
  ('SI0144', 'Aloo Gobi', 'Veg Curries & Dal', 'Veg', 140::numeric, 'Main Kitchen', 12::int),
  ('SI0145', 'Chana Masala', 'Veg Curries & Dal', 'Veg', 140::numeric, 'Main Kitchen', 12::int),
  ('SI0146', 'Rajma Masala', 'Veg Curries & Dal', 'Veg', 140::numeric, 'Main Kitchen', 14::int),
  ('SI0147', 'Baingan Bharta', 'Veg Curries & Dal', 'Veg', 150::numeric, 'Main Kitchen', 14::int),
  ('SI0148', 'Bhindi Masala', 'Veg Curries & Dal', 'Veg', 150::numeric, 'Main Kitchen', 12::int),
  ('SI0149', 'Mushroom Masala', 'Veg Curries & Dal', 'Veg', 170::numeric, 'Main Kitchen', 14::int),
  ('SI0150', 'Dal Makhani', 'Veg Curries & Dal', 'Veg', 170::numeric, 'Main Kitchen', 15::int),
  ('SI0151', 'Methi Malai Matar', 'Veg Curries & Dal', 'Veg', 180::numeric, 'Main Kitchen', 14::int),
  ('SI0152', 'Chicken Chettinad', 'Non-Veg Curries', 'Non-Veg', 240::numeric, 'Main Kitchen', 18::int),
  ('SI0153', 'Andhra Chicken Curry', 'Non-Veg Curries', 'Non-Veg', 230::numeric, 'Main Kitchen', 18::int),
  ('SI0154', 'Kerala Chicken Curry (Nadan)', 'Non-Veg Curries', 'Non-Veg', 230::numeric, 'Main Kitchen', 18::int),
  ('SI0155', 'Kerala Chicken Roast', 'Non-Veg Curries', 'Non-Veg', 250::numeric, 'Main Kitchen', 20::int),
  ('SI0156', 'Chicken Ghee Roast (Mangalorean)', 'Non-Veg Curries', 'Non-Veg', 260::numeric, 'Main Kitchen', 18::int),
  ('SI0157', 'Kori Gassi', 'Non-Veg Curries', 'Non-Veg', 250::numeric, 'Main Kitchen', 18::int),
  ('SI0158', 'Pepper Chicken', 'Non-Veg Curries', 'Non-Veg', 240::numeric, 'Main Kitchen', 16::int),
  ('SI0159', 'Natu Kodi Pulusu (Country Chicken)', 'Non-Veg Curries', 'Non-Veg', 280::numeric, 'Main Kitchen', 25::int),
  ('SI0160', 'Nattu Kozhi Varuval', 'Non-Veg Curries', 'Non-Veg', 300::numeric, 'Main Kitchen', 25::int),
  ('SI0161', 'Pallipalayam Chicken', 'Non-Veg Curries', 'Non-Veg', 250::numeric, 'Main Kitchen', 18::int),
  ('SI0162', 'Chicken Butter Masala', 'Non-Veg Curries', 'Non-Veg', 260::numeric, 'Main Kitchen', 18::int),
  ('SI0163', 'Chicken Tikka Masala', 'Non-Veg Curries', 'Non-Veg', 270::numeric, 'Main Kitchen', 18::int),
  ('SI0164', 'Kadai Chicken', 'Non-Veg Curries', 'Non-Veg', 250::numeric, 'Main Kitchen', 16::int),
  ('SI0165', 'Chicken Korma', 'Non-Veg Curries', 'Non-Veg', 250::numeric, 'Main Kitchen', 18::int),
  ('SI0166', 'Mutton Chukka', 'Non-Veg Curries', 'Non-Veg', 330::numeric, 'Main Kitchen', 25::int),
  ('SI0167', 'Mutton Pepper Fry', 'Non-Veg Curries', 'Non-Veg', 340::numeric, 'Main Kitchen', 25::int),
  ('SI0168', 'Mutton Rogan Josh', 'Non-Veg Curries', 'Non-Veg', 340::numeric, 'Main Kitchen', 25::int),
  ('SI0169', 'Mutton Curry (Nadan)', 'Non-Veg Curries', 'Non-Veg', 320::numeric, 'Main Kitchen', 25::int),
  ('SI0170', 'Gongura Mutton', 'Non-Veg Curries', 'Non-Veg', 350::numeric, 'Main Kitchen', 28::int),
  ('SI0171', 'Keema Masala', 'Non-Veg Curries', 'Non-Veg', 290::numeric, 'Main Kitchen', 18::int),
  ('SI0172', 'Mutton Paya', 'Non-Veg Curries', 'Non-Veg', 260::numeric, 'Main Kitchen', 30::int),
  ('SI0173', 'Haleem', 'Non-Veg Curries', 'Non-Veg', 250::numeric, 'Main Kitchen', 15::int),
  ('SI0174', 'Egg Curry', 'Non-Veg Curries', 'Egg', 140::numeric, 'Main Kitchen', 12::int),
  ('SI0175', 'Kerala Egg Roast', 'Non-Veg Curries', 'Egg', 150::numeric, 'Main Kitchen', 14::int),
  ('SI0176', 'Egg Masala', 'Non-Veg Curries', 'Egg', 140::numeric, 'Main Kitchen', 12::int),
  ('SI0177', 'Kerala Beef Fry', 'Non-Veg Curries', 'Non-Veg', 280::numeric, 'Main Kitchen', 22::int),
  ('SI0178', 'Beef Ularthiyathu', 'Non-Veg Curries', 'Non-Veg', 290::numeric, 'Main Kitchen', 25::int),
  ('SI0179', 'Butter Chicken', 'Non-Veg Curries', 'Non-Veg', 270::numeric, 'Main Kitchen', 18::int),
  ('SI0180', 'Chicken Do Pyaza', 'Non-Veg Curries', 'Non-Veg', 260::numeric, 'Main Kitchen', 18::int),
  ('SI0181', 'Kerala Fish Curry (Meen Curry)', 'Seafood', 'Non-Veg', 260::numeric, 'Main Kitchen', 18::int),
  ('SI0182', 'Fish Fry (Tawa)', 'Seafood', 'Non-Veg', 260::numeric, 'Main Kitchen', 15::int),
  ('SI0183', 'Karimeen Pollichathu', 'Seafood', 'Non-Veg', 480::numeric, 'Main Kitchen', 25::int),
  ('SI0184', 'Prawn Masala', 'Seafood', 'Non-Veg', 320::numeric, 'Main Kitchen', 18::int),
  ('SI0185', 'Prawn Ghee Roast', 'Seafood', 'Non-Veg', 340::numeric, 'Main Kitchen', 18::int),
  ('SI0186', 'Chettinad Fish Curry', 'Seafood', 'Non-Veg', 270::numeric, 'Main Kitchen', 18::int),
  ('SI0187', 'Andhra Fish Pulusu', 'Seafood', 'Non-Veg', 270::numeric, 'Main Kitchen', 18::int),
  ('SI0188', 'Mangalorean Fish Curry', 'Seafood', 'Non-Veg', 270::numeric, 'Main Kitchen', 18::int),
  ('SI0189', 'Squid Pepper Fry', 'Seafood', 'Non-Veg', 300::numeric, 'Main Kitchen', 18::int),
  ('SI0190', 'Crab Masala', 'Seafood', 'Non-Veg', 380::numeric, 'Main Kitchen', 25::int),
  ('SI0191', 'Nethili Fry (Anchovy)', 'Seafood', 'Non-Veg', 220::numeric, 'Main Kitchen', 12::int),
  ('SI0192', 'Pomfret Fry', 'Seafood', 'Non-Veg', 450::numeric, 'Main Kitchen', 18::int),
  ('SI0193', 'Fish Moilee', 'Seafood', 'Non-Veg', 290::numeric, 'Main Kitchen', 18::int),
  ('SI0194', 'Prawn Fry', 'Seafood', 'Non-Veg', 320::numeric, 'Main Kitchen', 15::int),
  ('SI0195', 'Vanjaram (Seer Fish) Fry', 'Seafood', 'Non-Veg', 450::numeric, 'Main Kitchen', 18::int),
  ('SI0196', 'Goan Fish Curry', 'Seafood', 'Non-Veg', 280::numeric, 'Main Kitchen', 18::int),
  ('SI0197', 'Gobi 65', 'Starters - Veg', 'Veg', 160::numeric, 'Main Kitchen', 12::int),
  ('SI0198', 'Paneer 65', 'Starters - Veg', 'Veg', 190::numeric, 'Main Kitchen', 14::int),
  ('SI0199', 'Gobi Manchurian', 'Starters - Veg', 'Veg', 170::numeric, 'Main Kitchen', 12::int),
  ('SI0200', 'Paneer Tikka', 'Starters - Veg', 'Veg', 210::numeric, 'Tandoor', 15::int),
  ('SI0201', 'Hara Bhara Kebab', 'Starters - Veg', 'Veg', 180::numeric, 'Tandoor', 14::int),
  ('SI0202', 'Veg Cutlet', 'Starters - Veg', 'Veg', 120::numeric, 'Main Kitchen', 10::int),
  ('SI0203', 'Mushroom Pepper Fry', 'Starters - Veg', 'Veg', 170::numeric, 'Main Kitchen', 12::int),
  ('SI0204', 'Baby Corn Fry', 'Starters - Veg', 'Veg', 170::numeric, 'Main Kitchen', 12::int),
  ('SI0205', 'Paneer Pakoda', 'Starters - Veg', 'Veg', 170::numeric, 'Main Kitchen', 12::int),
  ('SI0206', 'Onion Pakoda', 'Starters - Veg', 'Veg', 80::numeric, 'Main Kitchen', 10::int),
  ('SI0207', 'Mixed Veg Bajji', 'Starters - Veg', 'Veg', 80::numeric, 'Main Kitchen', 10::int),
  ('SI0208', 'Aloo 65', 'Starters - Veg', 'Veg', 150::numeric, 'Main Kitchen', 12::int),
  ('SI0209', 'Crispy Corn', 'Starters - Veg', 'Veg', 140::numeric, 'Main Kitchen', 10::int),
  ('SI0210', 'Veg Spring Roll', 'Starters - Veg', 'Veg', 140::numeric, 'Main Kitchen', 12::int),
  ('SI0211', 'Veg Samosa (2 pcs)', 'Starters - Veg', 'Veg', 40::numeric, 'Main Kitchen', 8::int),
  ('SI0212', 'Veg Seekh Kebab', 'Starters - Veg', 'Veg', 180::numeric, 'Tandoor', 14::int),
  ('SI0213', 'Cauliflower Pepper Fry', 'Starters - Veg', 'Veg', 150::numeric, 'Main Kitchen', 12::int),
  ('SI0214', 'Kerala Banana Chips', 'Starters - Veg', 'Veg', 60::numeric, 'Main Kitchen', 2::int),
  ('SI0215', 'Murukku', 'Starters - Veg', 'Veg', 50::numeric, 'Main Kitchen', 2::int),
  ('SI0216', 'Chilli Paneer (Dry)', 'Starters - Veg', 'Veg', 200::numeric, 'Main Kitchen', 14::int),
  ('SI0217', 'Chicken 65', 'Starters - Non-Veg', 'Non-Veg', 220::numeric, 'Main Kitchen', 15::int),
  ('SI0218', 'Chicken Lollipop', 'Starters - Non-Veg', 'Non-Veg', 240::numeric, 'Main Kitchen', 15::int),
  ('SI0219', 'Apollo Fish', 'Starters - Non-Veg', 'Non-Veg', 280::numeric, 'Main Kitchen', 15::int),
  ('SI0220', 'Chilli Chicken', 'Starters - Non-Veg', 'Non-Veg', 230::numeric, 'Main Kitchen', 14::int),
  ('SI0221', 'Chicken Manchurian', 'Starters - Non-Veg', 'Non-Veg', 230::numeric, 'Main Kitchen', 14::int),
  ('SI0222', 'Pepper Chicken Dry', 'Starters - Non-Veg', 'Non-Veg', 240::numeric, 'Main Kitchen', 15::int),
  ('SI0223', 'Chicken Tikka', 'Starters - Non-Veg', 'Non-Veg', 250::numeric, 'Tandoor', 18::int),
  ('SI0224', 'Tandoori Chicken (Half)', 'Starters - Non-Veg', 'Non-Veg', 260::numeric, 'Tandoor', 22::int),
  ('SI0225', 'Tandoori Chicken (Full)', 'Starters - Non-Veg', 'Non-Veg', 480::numeric, 'Tandoor', 28::int),
  ('SI0226', 'Chicken Seekh Kebab', 'Starters - Non-Veg', 'Non-Veg', 260::numeric, 'Tandoor', 16::int),
  ('SI0227', 'Mutton Seekh Kebab', 'Starters - Non-Veg', 'Non-Veg', 320::numeric, 'Tandoor', 18::int),
  ('SI0228', 'Chicken Majestic', 'Starters - Non-Veg', 'Non-Veg', 250::numeric, 'Main Kitchen', 15::int),
  ('SI0229', 'Kerala Fried Chicken', 'Starters - Non-Veg', 'Non-Veg', 240::numeric, 'Main Kitchen', 15::int),
  ('SI0230', 'Mutton Kola Urundai', 'Starters - Non-Veg', 'Non-Veg', 230::numeric, 'Main Kitchen', 15::int),
  ('SI0231', 'Egg Pepper Fry', 'Starters - Non-Veg', 'Egg', 160::numeric, 'Main Kitchen', 10::int),
  ('SI0232', 'Chicken Cutlet', 'Starters - Non-Veg', 'Non-Veg', 160::numeric, 'Main Kitchen', 12::int),
  ('SI0233', 'Prawn 65', 'Starters - Non-Veg', 'Non-Veg', 330::numeric, 'Main Kitchen', 15::int),
  ('SI0234', 'Fish Fingers', 'Starters - Non-Veg', 'Non-Veg', 260::numeric, 'Main Kitchen', 14::int),
  ('SI0235', 'Chicken Popcorn', 'Starters - Non-Veg', 'Non-Veg', 200::numeric, 'Main Kitchen', 12::int),
  ('SI0236', 'Kerala Parotta (1 pc)', 'Breads & Parotta', 'Veg', 25::numeric, 'Main Kitchen', 8::int),
  ('SI0237', 'Chilli Parotta', 'Breads & Parotta', 'Veg', 140::numeric, 'Main Kitchen', 12::int),
  ('SI0238', 'Veg Kothu Parotta', 'Breads & Parotta', 'Veg', 120::numeric, 'Main Kitchen', 14::int),
  ('SI0239', 'Egg Kothu Parotta', 'Breads & Parotta', 'Egg', 150::numeric, 'Main Kitchen', 14::int),
  ('SI0240', 'Chicken Kothu Parotta', 'Breads & Parotta', 'Non-Veg', 180::numeric, 'Main Kitchen', 15::int),
  ('SI0241', 'Mutton Kothu Parotta', 'Breads & Parotta', 'Non-Veg', 230::numeric, 'Main Kitchen', 18::int),
  ('SI0242', 'Veechu Parotta', 'Breads & Parotta', 'Veg', 40::numeric, 'Main Kitchen', 10::int),
  ('SI0243', 'Chapati', 'Breads & Parotta', 'Veg', 25::numeric, 'Main Kitchen', 6::int),
  ('SI0244', 'Phulka', 'Breads & Parotta', 'Veg', 20::numeric, 'Main Kitchen', 5::int),
  ('SI0245', 'Plain Naan', 'Breads & Parotta', 'Veg', 50::numeric, 'Tandoor', 8::int),
  ('SI0246', 'Butter Naan', 'Breads & Parotta', 'Veg', 60::numeric, 'Tandoor', 8::int),
  ('SI0247', 'Garlic Naan', 'Breads & Parotta', 'Veg', 70::numeric, 'Tandoor', 8::int),
  ('SI0248', 'Kulcha', 'Breads & Parotta', 'Veg', 60::numeric, 'Tandoor', 8::int),
  ('SI0249', 'Tandoori Roti', 'Breads & Parotta', 'Veg', 30::numeric, 'Tandoor', 6::int),
  ('SI0250', 'Rumali Roti', 'Breads & Parotta', 'Veg', 40::numeric, 'Tandoor', 8::int),
  ('SI0251', 'Lachha Paratha', 'Breads & Parotta', 'Veg', 50::numeric, 'Tandoor', 8::int),
  ('SI0252', 'Aloo Paratha', 'Breads & Parotta', 'Veg', 80::numeric, 'Main Kitchen', 10::int),
  ('SI0253', 'Bhatura (2 pcs)', 'Breads & Parotta', 'Veg', 60::numeric, 'Main Kitchen', 8::int),
  ('SI0254', 'Jolada Rotti', 'Breads & Parotta', 'Veg', 50::numeric, 'Main Kitchen', 8::int),
  ('SI0255', 'Palappam', 'Breads & Parotta', 'Veg', 30::numeric, 'Main Kitchen', 8::int),
  ('SI0256', 'Ragi Roti', 'Breads & Parotta', 'Veg', 50::numeric, 'Main Kitchen', 8::int),
  ('SI0257', 'Egg Parotta', 'Breads & Parotta', 'Egg', 60::numeric, 'Main Kitchen', 10::int),
  ('SI0258', 'Veg Fried Rice', 'Indo-Chinese', 'Veg', 130::numeric, 'Chinese', 12::int),
  ('SI0259', 'Schezwan Fried Rice', 'Indo-Chinese', 'Veg', 150::numeric, 'Chinese', 12::int),
  ('SI0260', 'Chicken Fried Rice', 'Indo-Chinese', 'Non-Veg', 170::numeric, 'Chinese', 12::int),
  ('SI0261', 'Veg Noodles', 'Indo-Chinese', 'Veg', 130::numeric, 'Chinese', 12::int),
  ('SI0262', 'Hakka Noodles (Veg)', 'Indo-Chinese', 'Veg', 140::numeric, 'Chinese', 12::int),
  ('SI0263', 'Chicken Noodles', 'Indo-Chinese', 'Non-Veg', 170::numeric, 'Chinese', 12::int),
  ('SI0264', 'Schezwan Noodles', 'Indo-Chinese', 'Veg', 160::numeric, 'Chinese', 12::int),
  ('SI0265', 'Veg Manchurian (Gravy)', 'Indo-Chinese', 'Veg', 160::numeric, 'Chinese', 14::int),
  ('SI0266', 'Chilli Gobi', 'Indo-Chinese', 'Veg', 160::numeric, 'Chinese', 12::int),
  ('SI0267', 'American Chop Suey', 'Indo-Chinese', 'Veg', 180::numeric, 'Chinese', 14::int),
  ('SI0268', 'Veg Manchow Soup', 'Indo-Chinese', 'Veg', 90::numeric, 'Chinese', 8::int),
  ('SI0269', 'Hot and Sour Soup', 'Indo-Chinese', 'Veg', 90::numeric, 'Chinese', 8::int),
  ('SI0270', 'Sweet Corn Soup', 'Indo-Chinese', 'Veg', 90::numeric, 'Chinese', 8::int),
  ('SI0271', 'Chicken Manchow Soup', 'Indo-Chinese', 'Non-Veg', 110::numeric, 'Chinese', 10::int),
  ('SI0272', 'Triple Schezwan Rice', 'Indo-Chinese', 'Non-Veg', 200::numeric, 'Chinese', 15::int),
  ('SI0273', 'Chicken Schezwan Noodles', 'Indo-Chinese', 'Non-Veg', 180::numeric, 'Chinese', 12::int),
  ('SI0274', 'Egg Noodles', 'Indo-Chinese', 'Egg', 150::numeric, 'Chinese', 12::int),
  ('SI0275', 'Chilli Chicken Gravy', 'Indo-Chinese', 'Non-Veg', 240::numeric, 'Chinese', 14::int),
  ('SI0276', 'Pani Puri (6 pcs)', 'Chaats & Snacks', 'Veg', 50::numeric, 'Main Kitchen', 5::int),
  ('SI0277', 'Sev Puri', 'Chaats & Snacks', 'Veg', 60::numeric, 'Main Kitchen', 5::int),
  ('SI0278', 'Bhel Puri', 'Chaats & Snacks', 'Veg', 60::numeric, 'Main Kitchen', 5::int),
  ('SI0279', 'Dahi Puri', 'Chaats & Snacks', 'Veg', 70::numeric, 'Main Kitchen', 5::int),
  ('SI0280', 'Masala Puri', 'Chaats & Snacks', 'Veg', 60::numeric, 'Main Kitchen', 6::int),
  ('SI0281', 'Samosa Chaat', 'Chaats & Snacks', 'Veg', 70::numeric, 'Main Kitchen', 6::int),
  ('SI0282', 'Pav Bhaji', 'Chaats & Snacks', 'Veg', 110::numeric, 'Main Kitchen', 12::int),
  ('SI0283', 'Vada Pav', 'Chaats & Snacks', 'Veg', 40::numeric, 'Main Kitchen', 6::int),
  ('SI0284', 'Dabeli', 'Chaats & Snacks', 'Veg', 50::numeric, 'Main Kitchen', 6::int),
  ('SI0285', 'Kachori', 'Chaats & Snacks', 'Veg', 40::numeric, 'Main Kitchen', 6::int),
  ('SI0286', 'Aloo Tikki Chaat', 'Chaats & Snacks', 'Veg', 80::numeric, 'Main Kitchen', 8::int),
  ('SI0287', 'Papdi Chaat', 'Chaats & Snacks', 'Veg', 70::numeric, 'Main Kitchen', 6::int),
  ('SI0288', 'Dhokla', 'Chaats & Snacks', 'Veg', 70::numeric, 'Main Kitchen', 6::int),
  ('SI0289', 'Khandvi', 'Chaats & Snacks', 'Veg', 70::numeric, 'Main Kitchen', 6::int),
  ('SI0290', 'Chana Sundal', 'Chaats & Snacks', 'Veg', 40::numeric, 'Main Kitchen', 5::int),
  ('SI0291', 'Pazham Pori (Banana Fry)', 'Chaats & Snacks', 'Veg', 40::numeric, 'Main Kitchen', 8::int),
  ('SI0292', 'Unniyappam', 'Chaats & Snacks', 'Veg', 50::numeric, 'Main Kitchen', 8::int),
  ('SI0293', 'Ela Ada', 'Chaats & Snacks', 'Veg', 50::numeric, 'Main Kitchen', 8::int),
  ('SI0294', 'Punugulu', 'Chaats & Snacks', 'Veg', 60::numeric, 'Main Kitchen', 8::int),
  ('SI0295', 'Egg Puff', 'Chaats & Snacks', 'Egg', 30::numeric, 'Main Kitchen', 2::int),
  ('SI0296', 'Veg Puff', 'Chaats & Snacks', 'Veg', 25::numeric, 'Main Kitchen', 2::int),
  ('SI0297', 'Chicken Puff', 'Chaats & Snacks', 'Non-Veg', 40::numeric, 'Main Kitchen', 2::int),
  ('SI0298', 'South Indian Mixture', 'Chaats & Snacks', 'Veg', 40::numeric, 'Main Kitchen', 2::int),
  ('SI0299', 'Misal Pav', 'Chaats & Snacks', 'Veg', 90::numeric, 'Main Kitchen', 10::int),
  ('SI0300', 'Poha', 'Chaats & Snacks', 'Veg', 50::numeric, 'Main Kitchen', 8::int),
  ('SI0301', 'Samosa (Single)', 'Chaats & Snacks', 'Veg', 20::numeric, 'Main Kitchen', 5::int),
  ('SI0302', 'Corn Chaat', 'Chaats & Snacks', 'Veg', 60::numeric, 'Main Kitchen', 6::int),
  ('SI0303', 'Bonda Soup', 'Chaats & Snacks', 'Veg', 60::numeric, 'Main Kitchen', 8::int),
  ('SI0304', 'Pepper Rasam', 'Soups, Rasam & Sides', 'Veg', 55::numeric, 'Main Kitchen', 5::int),
  ('SI0305', 'Lemon Rasam', 'Soups, Rasam & Sides', 'Veg', 50::numeric, 'Main Kitchen', 5::int),
  ('SI0306', 'Mutton Soup (Paya)', 'Soups, Rasam & Sides', 'Non-Veg', 140::numeric, 'Main Kitchen', 10::int),
  ('SI0307', 'Chicken Soup', 'Soups, Rasam & Sides', 'Non-Veg', 100::numeric, 'Main Kitchen', 8::int),
  ('SI0308', 'Nattu Kozhi Soup', 'Soups, Rasam & Sides', 'Non-Veg', 120::numeric, 'Main Kitchen', 10::int),
  ('SI0309', 'Veg Clear Soup', 'Soups, Rasam & Sides', 'Veg', 80::numeric, 'Main Kitchen', 8::int),
  ('SI0310', 'Curd (Bowl)', 'Soups, Rasam & Sides', 'Veg', 30::numeric, 'Main Kitchen', 2::int),
  ('SI0311', 'Boondi Raita', 'Soups, Rasam & Sides', 'Veg', 50::numeric, 'Main Kitchen', 3::int),
  ('SI0312', 'Onion Raita', 'Soups, Rasam & Sides', 'Veg', 50::numeric, 'Main Kitchen', 3::int),
  ('SI0313', 'Papad (Roasted)', 'Soups, Rasam & Sides', 'Veg', 20::numeric, 'Main Kitchen', 2::int),
  ('SI0314', 'Pickle (Mango/Gongura)', 'Soups, Rasam & Sides', 'Veg', 20::numeric, 'Main Kitchen', 1::int),
  ('SI0315', 'Green Salad', 'Soups, Rasam & Sides', 'Veg', 60::numeric, 'Main Kitchen', 4::int),
  ('SI0316', 'Onion Salad', 'Soups, Rasam & Sides', 'Veg', 30::numeric, 'Main Kitchen', 2::int),
  ('SI0317', 'Kachumber Salad', 'Soups, Rasam & Sides', 'Veg', 60::numeric, 'Main Kitchen', 4::int),
  ('SI0318', 'Extra Coconut Chutney', 'Soups, Rasam & Sides', 'Veg', 20::numeric, 'Main Kitchen', 1::int),
  ('SI0319', 'Extra Sambar', 'Soups, Rasam & Sides', 'Veg', 30::numeric, 'Main Kitchen', 2::int),
  ('SI0320', 'Gunpowder (Podi) with Gingelly Oil', 'Soups, Rasam & Sides', 'Veg', 20::numeric, 'Main Kitchen', 1::int),
  ('SI0321', 'Kerala Pappadam', 'Soups, Rasam & Sides', 'Veg', 20::numeric, 'Main Kitchen', 2::int),
  ('SI0322', 'Gulab Jamun (2 pcs)', 'Desserts & Sweets', 'Veg', 60::numeric, 'Dessert', 3::int),
  ('SI0323', 'Rasmalai (2 pcs)', 'Desserts & Sweets', 'Veg', 80::numeric, 'Dessert', 3::int),
  ('SI0324', 'Mysore Pak', 'Desserts & Sweets', 'Veg', 70::numeric, 'Dessert', 2::int),
  ('SI0325', 'Semiya Payasam', 'Desserts & Sweets', 'Veg', 70::numeric, 'Dessert', 4::int),
  ('SI0326', 'Palada Payasam', 'Desserts & Sweets', 'Veg', 80::numeric, 'Dessert', 4::int),
  ('SI0327', 'Double Ka Meetha', 'Desserts & Sweets', 'Veg', 80::numeric, 'Dessert', 5::int),
  ('SI0328', 'Qubani Ka Meetha', 'Desserts & Sweets', 'Veg', 90::numeric, 'Dessert', 5::int),
  ('SI0329', 'Jalebi', 'Desserts & Sweets', 'Veg', 60::numeric, 'Dessert', 5::int),
  ('SI0330', 'Badam Halwa', 'Desserts & Sweets', 'Veg', 90::numeric, 'Dessert', 5::int),
  ('SI0331', 'Carrot Halwa (Gajar Halwa)', 'Desserts & Sweets', 'Veg', 90::numeric, 'Dessert', 5::int),
  ('SI0332', 'Ada Pradhaman', 'Desserts & Sweets', 'Veg', 90::numeric, 'Dessert', 5::int),
  ('SI0333', 'Obbattu (Holige)', 'Desserts & Sweets', 'Veg', 60::numeric, 'Dessert', 5::int),
  ('SI0334', 'Kozhukattai (2 pcs)', 'Desserts & Sweets', 'Veg', 50::numeric, 'Dessert', 5::int),
  ('SI0335', 'Rava Laddu', 'Desserts & Sweets', 'Veg', 40::numeric, 'Dessert', 2::int),
  ('SI0336', 'Boondi Laddu', 'Desserts & Sweets', 'Veg', 40::numeric, 'Dessert', 2::int),
  ('SI0337', 'Tirunelveli Halwa', 'Desserts & Sweets', 'Veg', 80::numeric, 'Dessert', 2::int),
  ('SI0338', 'Ice Cream (Scoop)', 'Desserts & Sweets', 'Veg', 70::numeric, 'Dessert', 2::int),
  ('SI0339', 'Kulfi', 'Desserts & Sweets', 'Veg', 80::numeric, 'Dessert', 2::int),
  ('SI0340', 'Falooda', 'Desserts & Sweets', 'Veg', 140::numeric, 'Dessert', 6::int),
  ('SI0341', 'Fruit Salad with Ice Cream', 'Desserts & Sweets', 'Veg', 120::numeric, 'Dessert', 6::int),
  ('SI0342', 'Sheer Khurma', 'Desserts & Sweets', 'Veg', 90::numeric, 'Dessert', 5::int),
  ('SI0343', 'Kheer', 'Desserts & Sweets', 'Veg', 70::numeric, 'Dessert', 4::int),
  ('SI0344', 'Rasgulla (2 pcs)', 'Desserts & Sweets', 'Veg', 60::numeric, 'Dessert', 2::int),
  ('SI0345', 'Hot Gulab Jamun with Ice Cream', 'Desserts & Sweets', 'Veg', 110::numeric, 'Dessert', 5::int),
  ('SI0346', 'Bebinca', 'Desserts & Sweets', 'Veg', 90::numeric, 'Dessert', 3::int),
  ('SI0347', 'Sandesh', 'Desserts & Sweets', 'Veg', 60::numeric, 'Dessert', 2::int),
  ('SI0348', 'Coconut Burfi', 'Desserts & Sweets', 'Veg', 40::numeric, 'Dessert', 2::int),
  ('SI0349', 'Payasam (Pal)', 'Desserts & Sweets', 'Veg', 70::numeric, 'Dessert', 4::int),
  ('SI0350', 'Filter Coffee', 'Hot Beverages', 'Beverage', 30::numeric, 'Beverage Bar', 4::int),
  ('SI0351', 'Tea (Chai)', 'Hot Beverages', 'Beverage', 20::numeric, 'Beverage Bar', 4::int),
  ('SI0352', 'Masala Tea', 'Hot Beverages', 'Beverage', 25::numeric, 'Beverage Bar', 4::int),
  ('SI0353', 'Ginger Tea', 'Hot Beverages', 'Beverage', 25::numeric, 'Beverage Bar', 4::int),
  ('SI0354', 'Lemon Tea', 'Hot Beverages', 'Beverage', 25::numeric, 'Beverage Bar', 4::int),
  ('SI0355', 'Black Coffee', 'Hot Beverages', 'Beverage', 30::numeric, 'Beverage Bar', 3::int),
  ('SI0356', 'Instant Coffee', 'Hot Beverages', 'Beverage', 30::numeric, 'Beverage Bar', 3::int),
  ('SI0357', 'Hot Badam Milk', 'Hot Beverages', 'Beverage', 50::numeric, 'Beverage Bar', 4::int),
  ('SI0358', 'Horlicks', 'Hot Beverages', 'Beverage', 40::numeric, 'Beverage Bar', 3::int),
  ('SI0359', 'Boost', 'Hot Beverages', 'Beverage', 40::numeric, 'Beverage Bar', 3::int),
  ('SI0360', 'Hot Milk', 'Hot Beverages', 'Beverage', 30::numeric, 'Beverage Bar', 3::int),
  ('SI0361', 'Green Tea', 'Hot Beverages', 'Beverage', 30::numeric, 'Beverage Bar', 3::int),
  ('SI0362', 'Sukku Malli Coffee', 'Hot Beverages', 'Beverage', 35::numeric, 'Beverage Bar', 4::int),
  ('SI0363', 'Irani Chai', 'Hot Beverages', 'Beverage', 30::numeric, 'Beverage Bar', 4::int),
  ('SI0364', 'Kashayam (Herbal Drink)', 'Hot Beverages', 'Beverage', 40::numeric, 'Beverage Bar', 5::int),
  ('SI0365', 'Buttermilk (Majjiga)', 'Cold Beverages & Juices', 'Beverage', 30::numeric, 'Beverage Bar', 2::int),
  ('SI0366', 'Masala Chaas', 'Cold Beverages & Juices', 'Beverage', 35::numeric, 'Beverage Bar', 2::int),
  ('SI0367', 'Sweet Lassi', 'Cold Beverages & Juices', 'Beverage', 60::numeric, 'Beverage Bar', 3::int),
  ('SI0368', 'Mango Lassi', 'Cold Beverages & Juices', 'Beverage', 80::numeric, 'Beverage Bar', 3::int),
  ('SI0369', 'Rose Milk', 'Cold Beverages & Juices', 'Beverage', 50::numeric, 'Beverage Bar', 3::int),
  ('SI0370', 'Cold Badam Milk', 'Cold Beverages & Juices', 'Beverage', 60::numeric, 'Beverage Bar', 3::int),
  ('SI0371', 'Nannari Sarbath', 'Cold Beverages & Juices', 'Beverage', 40::numeric, 'Beverage Bar', 3::int),
  ('SI0372', 'Jigarthanda', 'Cold Beverages & Juices', 'Beverage', 90::numeric, 'Beverage Bar', 5::int),
  ('SI0373', 'Fresh Lime Soda', 'Cold Beverages & Juices', 'Beverage', 50::numeric, 'Beverage Bar', 3::int),
  ('SI0374', 'Fresh Lime Water', 'Cold Beverages & Juices', 'Beverage', 40::numeric, 'Beverage Bar', 3::int),
  ('SI0375', 'Tender Coconut Water', 'Cold Beverages & Juices', 'Beverage', 50::numeric, 'Beverage Bar', 2::int),
  ('SI0376', 'Sugarcane Juice', 'Cold Beverages & Juices', 'Beverage', 40::numeric, 'Beverage Bar', 3::int),
  ('SI0377', 'Watermelon Juice', 'Cold Beverages & Juices', 'Beverage', 60::numeric, 'Beverage Bar', 4::int),
  ('SI0378', 'Orange Juice', 'Cold Beverages & Juices', 'Beverage', 80::numeric, 'Beverage Bar', 4::int),
  ('SI0379', 'Pineapple Juice', 'Cold Beverages & Juices', 'Beverage', 70::numeric, 'Beverage Bar', 4::int),
  ('SI0380', 'Mosambi Juice', 'Cold Beverages & Juices', 'Beverage', 70::numeric, 'Beverage Bar', 4::int),
  ('SI0381', 'Mango Juice', 'Cold Beverages & Juices', 'Beverage', 80::numeric, 'Beverage Bar', 4::int),
  ('SI0382', 'Grape Juice', 'Cold Beverages & Juices', 'Beverage', 70::numeric, 'Beverage Bar', 4::int),
  ('SI0383', 'Pomegranate Juice', 'Cold Beverages & Juices', 'Beverage', 100::numeric, 'Beverage Bar', 4::int),
  ('SI0384', 'Muskmelon Juice', 'Cold Beverages & Juices', 'Beverage', 70::numeric, 'Beverage Bar', 4::int),
  ('SI0385', 'Mixed Fruit Juice', 'Cold Beverages & Juices', 'Beverage', 90::numeric, 'Beverage Bar', 5::int),
  ('SI0386', 'Banana Milkshake', 'Cold Beverages & Juices', 'Beverage', 80::numeric, 'Beverage Bar', 4::int),
  ('SI0387', 'Chikoo Milkshake', 'Cold Beverages & Juices', 'Beverage', 90::numeric, 'Beverage Bar', 4::int),
  ('SI0388', 'Chocolate Milkshake', 'Cold Beverages & Juices', 'Beverage', 100::numeric, 'Beverage Bar', 4::int),
  ('SI0389', 'Cold Coffee', 'Cold Beverages & Juices', 'Beverage', 90::numeric, 'Beverage Bar', 4::int),
  ('SI0390', 'Thandai', 'Cold Beverages & Juices', 'Beverage', 80::numeric, 'Beverage Bar', 4::int),
  ('SI0391', 'Soft Drink (300 ml)', 'Cold Beverages & Juices', 'Beverage', 30::numeric, 'Beverage Bar', 1::int),
  ('SI0392', 'Packaged Water (1 L)', 'Cold Beverages & Juices', 'Beverage', 20::numeric, 'Beverage Bar', 1::int),
  ('SI0393', 'Soda', 'Cold Beverages & Juices', 'Beverage', 25::numeric, 'Beverage Bar', 1::int),
  ('SI0394', 'Panakam', 'Cold Beverages & Juices', 'Beverage', 40::numeric, 'Beverage Bar', 3::int),
  ('SI0395', 'Ragi Malt', 'Cold Beverages & Juices', 'Beverage', 40::numeric, 'Beverage Bar', 4::int),
  ('SI0396', 'Kokum Sherbet', 'Cold Beverages & Juices', 'Beverage', 50::numeric, 'Beverage Bar', 3::int),
  ('SI0397', 'Neer Mor (Spiced)', 'Cold Beverages & Juices', 'Beverage', 30::numeric, 'Beverage Bar', 2::int),
  ('SI0398', 'Sarson da Saag with Makki Roti', 'Regional Favourites (Pan-India)', 'Veg', 180::numeric, 'Main Kitchen', 15::int),
  ('SI0399', 'Amritsari Kulcha', 'Regional Favourites (Pan-India)', 'Veg', 120::numeric, 'Main Kitchen', 12::int),
  ('SI0400', 'Chole Bhature', 'Regional Favourites (Pan-India)', 'Veg', 130::numeric, 'Main Kitchen', 12::int),
  ('SI0401', 'Rajma Chawal', 'Regional Favourites (Pan-India)', 'Veg', 130::numeric, 'Main Kitchen', 12::int),
  ('SI0402', 'Kadhi Pakora', 'Regional Favourites (Pan-India)', 'Veg', 130::numeric, 'Main Kitchen', 12::int),
  ('SI0403', 'Dal Baati Churma', 'Regional Favourites (Pan-India)', 'Veg', 190::numeric, 'Main Kitchen', 18::int),
  ('SI0404', 'Laal Maas', 'Regional Favourites (Pan-India)', 'Non-Veg', 330::numeric, 'Main Kitchen', 28::int),
  ('SI0405', 'Gatte Ki Sabzi', 'Regional Favourites (Pan-India)', 'Veg', 150::numeric, 'Main Kitchen', 14::int),
  ('SI0406', 'Thepla (3 pcs)', 'Regional Favourites (Pan-India)', 'Veg', 60::numeric, 'Main Kitchen', 6::int),
  ('SI0407', 'Undhiyu', 'Regional Favourites (Pan-India)', 'Veg', 160::numeric, 'Main Kitchen', 15::int),
  ('SI0408', 'Fafda Jalebi', 'Regional Favourites (Pan-India)', 'Veg', 70::numeric, 'Main Kitchen', 5::int),
  ('SI0409', 'Litti Chokha', 'Regional Favourites (Pan-India)', 'Veg', 100::numeric, 'Main Kitchen', 14::int),
  ('SI0410', 'Macher Jhol', 'Regional Favourites (Pan-India)', 'Non-Veg', 260::numeric, 'Main Kitchen', 18::int),
  ('SI0411', 'Shorshe Ilish', 'Regional Favourites (Pan-India)', 'Non-Veg', 480::numeric, 'Main Kitchen', 22::int),
  ('SI0412', 'Kosha Mangsho', 'Regional Favourites (Pan-India)', 'Non-Veg', 340::numeric, 'Main Kitchen', 28::int),
  ('SI0413', 'Luchi Aloo Dum', 'Regional Favourites (Pan-India)', 'Veg', 110::numeric, 'Main Kitchen', 12::int),
  ('SI0414', 'Veg Momos (6 pcs)', 'Regional Favourites (Pan-India)', 'Veg', 90::numeric, 'Main Kitchen', 10::int),
  ('SI0415', 'Chicken Momos (6 pcs)', 'Regional Favourites (Pan-India)', 'Non-Veg', 110::numeric, 'Main Kitchen', 10::int),
  ('SI0416', 'Thukpa', 'Regional Favourites (Pan-India)', 'Non-Veg', 120::numeric, 'Main Kitchen', 12::int),
  ('SI0417', 'Chicken Cafreal', 'Regional Favourites (Pan-India)', 'Non-Veg', 270::numeric, 'Main Kitchen', 18::int),
  ('SI0418', 'Pork Vindaloo', 'Regional Favourites (Pan-India)', 'Non-Veg', 300::numeric, 'Main Kitchen', 25::int),
  ('SI0419', 'Sorpotel', 'Regional Favourites (Pan-India)', 'Non-Veg', 280::numeric, 'Main Kitchen', 25::int),
  ('SI0420', 'Chicken Dhansak', 'Regional Favourites (Pan-India)', 'Non-Veg', 250::numeric, 'Main Kitchen', 20::int),
  ('SI0421', 'Dum Aloo Kashmiri', 'Regional Favourites (Pan-India)', 'Veg', 170::numeric, 'Main Kitchen', 15::int),
  ('SI0422', 'Gushtaba', 'Regional Favourites (Pan-India)', 'Non-Veg', 360::numeric, 'Main Kitchen', 28::int),
  ('SI0423', 'Pav Bhaji Pulao', 'Regional Favourites (Pan-India)', 'Veg', 140::numeric, 'Main Kitchen', 12::int),
  ('SI0424', 'Khichdi', 'Regional Favourites (Pan-India)', 'Veg', 100::numeric, 'Main Kitchen', 12::int),
  ('SI0425', 'Dal Khichdi with Ghee', 'Regional Favourites (Pan-India)', 'Veg', 120::numeric, 'Main Kitchen', 12::int),
  ('SI0426', 'Paneer Bhurji', 'Regional Favourites (Pan-India)', 'Veg', 170::numeric, 'Main Kitchen', 12::int),
  ('SI0427', 'Bombay Sandwich', 'Regional Favourites (Pan-India)', 'Veg', 70::numeric, 'Main Kitchen', 8::int),
  ('SI0428', 'Egg Bhurji', 'Regional Favourites (Pan-India)', 'Egg', 110::numeric, 'Main Kitchen', 8::int),
  ('SI0429', 'Anda Curry (Dhaba Style)', 'Regional Favourites (Pan-India)', 'Egg', 150::numeric, 'Main Kitchen', 12::int),
  ('SI0430', 'Kashmiri Kahwa', 'Regional Favourites (Pan-India)', 'Beverage', 60::numeric, 'Main Kitchen', 5::int)
) AS v(code, nm, cat, ft, pr, st, pt)
JOIN menu.category_master c ON c.category_name = v.cat
LEFT JOIN billing.tax_master t ON t.tax_name = 'GST 5%'
LEFT JOIN orders.kitchen_station k ON k.station_name = v.st
WHERE NOT EXISTS (SELECT 1 FROM menu.food_item_master f
                  WHERE f.food_name = v.nm AND f.category_id = c.category_id)
  AND NOT EXISTS (SELECT 1 FROM menu.food_item_master f WHERE f.item_code = v.code);

COMMIT;

-- Quick check (optional):
-- SELECT c.category_name, COUNT(*) FROM menu.food_item_master f
--   JOIN menu.category_master c USING (category_id) GROUP BY 1 ORDER BY 1;

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
