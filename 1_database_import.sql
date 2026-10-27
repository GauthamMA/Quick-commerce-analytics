CREATE TABLE IF NOT EXISTS stores (
    store_id VARCHAR(10),
    store_name VARCHAR(100),
    zone VARCHAR(50),
    neighborhood VARCHAR(100),
    latitude NUMERIC(10,6),
    longitude NUMERIC(10,6),
    opening_date DATE,
    area_sq_ft INTEGER,
    daily_capacity_orders INTEGER,
    customer_rating NUMERIC(3,1),
    status VARCHAR(20)
);


-- 1. CUSTOMERS
CREATE TABLE IF NOT EXISTS customers (
    customer_id TEXT,
    customer_name TEXT,
    gender TEXT,
    age_band TEXT,
    home_zone TEXT,
    neighborhood TEXT,
    signup_date DATE,
    customer_segment TEXT,
    loyalty_tier TEXT,
    acquisition_channel TEXT,
    preferred_category TEXT,
    marketing_opt_in BOOLEAN
);

-- 2. PRODUCTS
CREATE TABLE IF NOT EXISTS products (
    product_id TEXT,
    product_name TEXT,
    category TEXT,
    subcategory TEXT,
    brand TEXT,
    pack_size TEXT,
    list_price_inr NUMERIC(12,2),
    unit_cost_inr NUMERIC(12,2),
    shelf_life_days INTEGER,
    is_perishable BOOLEAN,
    abc_class TEXT,
    storage_type TEXT,
    is_active BOOLEAN
);

-- 3. RIDERS
CREATE TABLE IF NOT EXISTS riders (
    rider_id TEXT,
    rider_name TEXT,
    base_zone TEXT,
    vehicle_type TEXT,
    join_date DATE,
    preferred_shift TEXT,
    rider_rating NUMERIC(3,1),
    status TEXT
);

-- 4. PROMOTIONS
CREATE TABLE IF NOT EXISTS promotions (
    promo_id TEXT,
    promo_code TEXT,
    campaign_type TEXT,
    start_date DATE,
    end_date DATE,
    discount_type TEXT,
    discount_value NUMERIC(10,2),
    minimum_basket_inr NUMERIC(12,2),
    maximum_discount_inr NUMERIC(12,2),
    target_segment TEXT,
    target_zone TEXT,
    channel TEXT,
    is_active BOOLEAN
);

-- 5. PROMOTION EXPOSURES
CREATE TABLE IF NOT EXISTS promotion_exposures (
    exposure_id TEXT,
    promo_id TEXT,
    customer_id TEXT,
    assignment_group TEXT,
    assigned_date DATE,
    channel TEXT
);

-- 6. EXTERNAL FACTORS
CREATE TABLE IF NOT EXISTS external_factors (
    date DATE,
    zone TEXT,
    weather_condition TEXT,
    rainfall_mm NUMERIC(8,2),
    temperature_c NUMERIC(5,2),
    traffic_index NUMERIC(6,2),
    is_weekend BOOLEAN,
    is_holiday BOOLEAN,
    festival TEXT,
    local_event TEXT
);

-- 7. ORDERS
CREATE TABLE IF NOT EXISTS orders (
    order_id TEXT,
    customer_id TEXT,
    store_id TEXT,
    order_timestamp TIMESTAMP,
    zone TEXT,
    order_status TEXT,
    cancellation_reason TEXT,
    order_channel TEXT,
    payment_method TEXT,
    promo_id TEXT,
    item_count INTEGER,
    gross_merchandise_value_inr NUMERIC(14,2),
    discount_inr NUMERIC(14,2),
    delivery_fee_inr NUMERIC(12,2),
    tax_inr NUMERIC(12,2),
    refund_inr NUMERIC(14,2),
    net_revenue_inr NUMERIC(14,2),
    cost_of_goods_inr NUMERIC(14,2),
    gross_profit_inr NUMERIC(14,2),
    delivery_distance_km NUMERIC(8,2),
    promised_delivery_minutes INTEGER
);

-- 8. ORDER ITEMS
CREATE TABLE IF NOT EXISTS order_items (
    order_item_id TEXT,
    order_id TEXT,
    product_id TEXT,
    line_number INTEGER,
    requested_quantity INTEGER,
    quantity INTEGER,
    unit_price_inr NUMERIC(12,2),
    line_gross_inr NUMERIC(14,2),
    discount_allocated_inr NUMERIC(14,2),
    net_sales_inr NUMERIC(14,2),
    line_cost_inr NUMERIC(14,2),
    line_margin_inr NUMERIC(14,2),
    category TEXT,
    subcategory TEXT,
    stockout_flag BOOLEAN
);

-- 9. DELIVERIES
CREATE TABLE IF NOT EXISTS deliveries (
    delivery_id TEXT,
    order_id TEXT,
    rider_id TEXT,
    store_id TEXT,
    zone TEXT,
    accepted_timestamp TIMESTAMP,
    prepared_timestamp TIMESTAMP,
    picked_up_timestamp TIMESTAMP,
    delivered_timestamp TIMESTAMP,
    assignment_wait_minutes NUMERIC(8,2),
    preparation_minutes NUMERIC(8,2),
    travel_minutes NUMERIC(8,2),
    handoff_minutes NUMERIC(8,2),
    actual_delivery_minutes NUMERIC(8,2),
    promised_delivery_minutes INTEGER,
    is_late BOOLEAN,
    distance_km NUMERIC(8,2),
    traffic_index NUMERIC(6,2),
    rainfall_mm NUMERIC(8,2),
    customer_rating NUMERIC(3,1)
);

-- 10. INVENTORY
CREATE TABLE IF NOT EXISTS inventory (
    inventory_record_id TEXT,
    date DATE,
    store_id TEXT,
    product_id TEXT,
    opening_stock_units INTEGER,
    received_units INTEGER,
    sold_units INTEGER,
    expired_units INTEGER,
    damaged_units INTEGER,
    closing_stock_units INTEGER,
    stockout_minutes INTEGER,
    reorder_point_units INTEGER,
    supplier_lead_days INTEGER,
    wastage_cost_inr NUMERIC(14,2),
    below_reorder_point BOOLEAN
);

SELECT 'stores' AS table_name, COUNT(*) FROM stores
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'riders', COUNT(*) FROM riders
UNION ALL SELECT 'promotions', COUNT(*) FROM promotions
UNION ALL SELECT 'promotion_exposures', COUNT(*) FROM promotion_exposures
UNION ALL SELECT 'external_factors', COUNT(*) FROM external_factors
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'deliveries', COUNT(*) FROM deliveries
UNION ALL SELECT 'inventory', COUNT(*) FROM inventory
ORDER BY table_name;