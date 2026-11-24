-- =====================================================================
-- Restaurant operations: orders, kitchen, waiter, billing, UPI, queue
-- Run in pgAdmin on the RestaurantDB database AFTER RestaurantDB.sql.
-- Uses its own schema (pos) so it cannot clash with existing tables.
-- =====================================================================
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
