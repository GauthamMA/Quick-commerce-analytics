
-- ============================================================================
-- BENGALURU QUICK-COMMERCE ANALYTICS
-- File: 1_database_import.sql
-- Purpose: Create raw data tables and verify imported CSV record counts
-- Database: PostgreSQL
-- ============================================================================
--
-- This script defines the structure of the 11 raw data tables.
--
-- CSV files are imported separately after the tables are created.
-- Primary keys and foreign keys are intentionally not defined at this stage,
-- allowing the raw data to be inspected and cleaned before constraints
-- are introduced in the analytical model.
--
-- IF NOT EXISTS prevents an error when a table already exists.
-- It does not modify the structure of an existing table.
-- ============================================================================


-- ============================================================================
-- SECTION 1: CREATE RAW DATA TABLES
-- ============================================================================


-- 01. STORES
-- Stores location, operational capacity, and customer rating information.

CREATE TABLE IF NOT EXISTS stores (
    store_id                 VARCHAR(10),
    store_name               VARCHAR(100),
    zone                     VARCHAR(50),
    neighborhood             VARCHAR(100),
    latitude                 NUMERIC(10, 6),
    longitude                NUMERIC(10, 6),
    opening_date             DATE,
    area_sq_ft               INTEGER,
    daily_capacity_orders    INTEGER,
    customer_rating          NUMERIC(3, 1),
    status                   VARCHAR(20)
);


-- 02. CUSTOMERS
-- Contains customer demographics, segmentation, and acquisition information.

CREATE TABLE IF NOT EXISTS customers (
    customer_id          TEXT,
    customer_name        TEXT,
    gender               TEXT,
    age_band             TEXT,
    home_zone            TEXT,
    neighborhood         TEXT,
    signup_date          DATE,
    customer_segment     TEXT,
    loyalty_tier         TEXT,
    acquisition_channel  TEXT,
    preferred_category   TEXT,
    marketing_opt_in     BOOLEAN
);


-- 03. PRODUCTS
-- Product catalogue containing categories, pricing, costs, and shelf life.

CREATE TABLE IF NOT EXISTS products (
    product_id          TEXT,
    product_name        TEXT,
    category            TEXT,
    subcategory         TEXT,
    brand               TEXT,
    pack_size           TEXT,
    list_price_inr      NUMERIC(12, 2),
    unit_cost_inr       NUMERIC(12, 2),
    shelf_life_days     INTEGER,
    is_perishable       BOOLEAN,
    abc_class           TEXT,
    storage_type        TEXT,
    is_active           BOOLEAN
);


-- 04. RIDERS
-- Delivery partner details, including assigned zone and shift preferences.

CREATE TABLE IF NOT EXISTS riders (
    rider_id            TEXT,
    rider_name          TEXT,
    base_zone           TEXT,
    vehicle_type        TEXT,
    join_date           DATE,
    preferred_shift     TEXT,
    rider_rating        NUMERIC(3, 1),
    status              TEXT
);


-- 05. PROMOTIONS
-- Campaign definitions, discount rules, and target customer segments.

CREATE TABLE IF NOT EXISTS promotions (
    promo_id               TEXT,
    promo_code             TEXT,
    campaign_type          TEXT,
    start_date             DATE,
    end_date               DATE,
    discount_type          TEXT,
    discount_value         NUMERIC(10, 2),
    minimum_basket_inr     NUMERIC(12, 2),
    maximum_discount_inr   NUMERIC(12, 2),
    target_segment         TEXT,
    target_zone            TEXT,
    channel                TEXT,
    is_active              BOOLEAN
);


-- 06. PROMOTION EXPOSURES
-- Records which customers were assigned to promotional campaigns,
-- including their assignment groups for campaign comparison.

CREATE TABLE IF NOT EXISTS promotion_exposures (
    exposure_id         TEXT,
    promo_id            TEXT,
    customer_id         TEXT,
    assignment_group    TEXT,
    assigned_date       DATE,
    channel             TEXT
);


-- 07. EXTERNAL FACTORS
-- Daily weather, traffic, holidays, and local events by zone.

CREATE TABLE IF NOT EXISTS external_factors (
    date                DATE,
    zone                TEXT,
    weather_condition   TEXT,
    rainfall_mm         NUMERIC(8, 2),
    temperature_c       NUMERIC(5, 2),
    traffic_index       NUMERIC(6, 2),
    is_weekend          BOOLEAN,
    is_holiday          BOOLEAN,
    festival            TEXT,
    local_event         TEXT
);


-- 08. ORDERS
-- Order-level transactions, including financial values,
-- order status, delivery distance, and promised delivery time.

CREATE TABLE IF NOT EXISTS orders (
    order_id                    TEXT,
    customer_id                 TEXT,
    store_id                    TEXT,
    order_timestamp             TIMESTAMP,
    zone                        TEXT,
    order_status                TEXT,
    cancellation_reason         TEXT,
    order_channel               TEXT,
    payment_method              TEXT,
    promo_id                    TEXT,
    item_count                  INTEGER,
    gross_merchandise_value_inr NUMERIC(14, 2),
    discount_inr                NUMERIC(14, 2),
    delivery_fee_inr            NUMERIC(12, 2),
    tax_inr                     NUMERIC(12, 2),
    refund_inr                  NUMERIC(14, 2),
    net_revenue_inr             NUMERIC(14, 2),
    cost_of_goods_inr           NUMERIC(14, 2),
    gross_profit_inr            NUMERIC(14, 2),
    delivery_distance_km        NUMERIC(8, 2),
    promised_delivery_minutes   INTEGER
);


-- 09. ORDER ITEMS
-- Individual product lines within orders, including requested quantities,
-- fulfilled quantities, sales values, margins, and stockout indicators.

CREATE TABLE IF NOT EXISTS order_items (
    order_item_id           TEXT,
    order_id                TEXT,
    product_id              TEXT,
    line_number             INTEGER,
    requested_quantity      INTEGER,
    quantity                INTEGER,
    unit_price_inr          NUMERIC(12, 2),
    line_gross_inr          NUMERIC(14, 2),
    discount_allocated_inr  NUMERIC(14, 2),
    net_sales_inr           NUMERIC(14, 2),
    line_cost_inr           NUMERIC(14, 2),
    line_margin_inr         NUMERIC(14, 2),
    category                TEXT,
    subcategory             TEXT,
    stockout_flag           BOOLEAN
);


-- 10. DELIVERIES
-- Delivery events, rider assignments, operational durations,
-- lateness indicators, and external delivery conditions.

CREATE TABLE IF NOT EXISTS deliveries (
    delivery_id                 TEXT,
    order_id                    TEXT,
    rider_id                    TEXT,
    store_id                    TEXT,
    zone                        TEXT,
    accepted_timestamp          TIMESTAMP,
    prepared_timestamp          TIMESTAMP,
    picked_up_timestamp         TIMESTAMP,
    delivered_timestamp         TIMESTAMP,
    assignment_wait_minutes     NUMERIC(8, 2),
    preparation_minutes         NUMERIC(8, 2),
    travel_minutes              NUMERIC(8, 2),
    handoff_minutes             NUMERIC(8, 2),
    actual_delivery_minutes     NUMERIC(8, 2),
    promised_delivery_minutes   INTEGER,
    is_late                     BOOLEAN,
    distance_km                 NUMERIC(8, 2),
    traffic_index               NUMERIC(6, 2),
    rainfall_mm                 NUMERIC(8, 2),
    customer_rating             NUMERIC(3, 1)
);


-- 11. INVENTORY
-- Daily product-level inventory observations by store, including
-- stock movements, stockouts, reorder thresholds, and wastage costs.

CREATE TABLE IF NOT EXISTS inventory (
    inventory_record_id     TEXT,
    date                    DATE,
    store_id                TEXT,
    product_id              TEXT,
    opening_stock_units     INTEGER,
    received_units          INTEGER,
    sold_units              INTEGER,
    expired_units           INTEGER,
    damaged_units           INTEGER,
    closing_stock_units     INTEGER,
    stockout_minutes        INTEGER,
    reorder_point_units     INTEGER,
    supplier_lead_days      INTEGER,
    wastage_cost_inr        NUMERIC(14, 2),
    below_reorder_point     BOOLEAN
);


-- ============================================================================
-- SECTION 2: VERIFY DATA IMPORT
-- ============================================================================
--
-- After importing the CSV files, count the records in each raw table.
--
-- UNION ALL combines the individual table counts into one result.
-- The output is sorted alphabetically by table name.
--
-- These counts provide a baseline for subsequent data-quality checks.
-- ============================================================================

SELECT
    'stores' AS table_name,
    COUNT(*) AS row_count
FROM stores

UNION ALL

SELECT
    'customers',
    COUNT(*)
FROM customers

UNION ALL

SELECT
    'products',
    COUNT(*)
FROM products

UNION ALL

SELECT
    'riders',
    COUNT(*)
FROM riders

UNION ALL

SELECT
    'promotions',
    COUNT(*)
FROM promotions

UNION ALL

SELECT
    'promotion_exposures',
    COUNT(*)
FROM promotion_exposures

UNION ALL

SELECT
    'external_factors',
    COUNT(*)
FROM external_factors

UNION ALL

SELECT
    'orders',
    COUNT(*)
FROM orders

UNION ALL

SELECT
    'order_items',
    COUNT(*)
FROM order_items

UNION ALL

SELECT
    'deliveries',
    COUNT(*)
FROM deliveries

UNION ALL

SELECT
    'inventory',
    COUNT(*)
FROM inventory

ORDER BY table_name;
