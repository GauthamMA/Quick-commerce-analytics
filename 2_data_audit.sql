/*orders*/

SELECT * FROM orders;



SELECT
    COUNT(*) AS number_of_rows,
    COUNT(DISTINCT order_id) AS unique_rows,
    COUNT(*)-COUNT(DISTINCT order_id) AS duplicate_rows
FROM orders;
SELECT
    COUNT(order_id) AS num_of_duplicates,
    order_id,
    COUNT(DISTINCT TO_JSONB(orders)) AS distinct_versions
FROM orders 
GROUP BY order_id
HAVING COUNT(order_id) >1
ORDER BY order_id;

CREATE TABLE orders_clean AS
SELECT DISTINCT *
FROM orders;

SELECT
    COUNT(*) AS number_of_rows,
    COUNT(DISTINCT order_id) AS unique_rows,
    COUNT(*)-COUNT(DISTINCT order_id) AS duplicate_rows
FROM orders_clean;

/*order_items*/

SELECT * FROM order_items;

SELECT
    COUNT(*) AS number_of_rows,
    COUNT(DISTINCT order_item_id) AS unique_rows,
    COUNT(*)-COUNT(DISTINCT order_item_id) AS duplicate_rows
FROM order_items;

SELECT DISTINCT *
FROM order_items;

CREATE TABLE order_items_clean AS
SELECT DISTINCT *
FROM order_items;

SELECT
    COUNT(*) AS number_of_rows,
    COUNT(DISTINCT order_item_id) AS unique_rows,
    COUNT(*)-COUNT(DISTINCT order_item_id) AS duplicate_rows
FROM order_items_clean;

/*inventory*/

SELECT * FROM inventory LIMIT 10;

SELECT
    COUNT(*) AS number_of_rows,
    COUNT(DISTINCT inventory_record_id) AS unique_rows,
    COUNT(*)-COUNT(DISTINCT inventory_record_id) AS duplicate_rows
FROM inventory;


CREATE TABLE inventory_clean AS
SELECT DISTINCT *
FROM inventory;

SELECT
    COUNT(*) AS number_of_rows,
    COUNT(DISTINCT inventory_record_id) AS unique_rows,
    COUNT(*)-COUNT(DISTINCT inventory_record_id) AS duplicate_rows
FROM inventory_clean;

/*Remaining tables together*/

SELECT
    'customers' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS unique_keys,
    COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_rows
FROM customers

UNION ALL

SELECT
    'products',
    COUNT(*),
    COUNT(DISTINCT product_id),
    COUNT(*) - COUNT(DISTINCT product_id)
FROM products

UNION ALL

SELECT
    'stores',
    COUNT(*),
    COUNT(DISTINCT store_id),
    COUNT(*) - COUNT(DISTINCT store_id)
FROM stores

UNION ALL

SELECT
    'riders',
    COUNT(*),
    COUNT(DISTINCT rider_id),
    COUNT(*) - COUNT(DISTINCT rider_id)
FROM riders

UNION ALL

SELECT
    'promotions',
    COUNT(*),
    COUNT(DISTINCT promo_id),
    COUNT(*) - COUNT(DISTINCT promo_id)
FROM promotions

UNION ALL

SELECT
    'promotion_exposures',
    COUNT(*),
    COUNT(DISTINCT exposure_id),
    COUNT(*) - COUNT(DISTINCT exposure_id)
FROM promotion_exposures

UNION ALL

SELECT
    'deliveries',
    COUNT(*),
    COUNT(DISTINCT delivery_id),
    COUNT(*) - COUNT(DISTINCT delivery_id)
FROM deliveries

UNION ALL

SELECT
    'external_factors',
    COUNT(*),
    COUNT(DISTINCT (date,zone)),
    COUNT(*) - COUNT(DISTINCT (date,zone))
FROM external_factors;

/*Missing value check*/

SELECT
    COUNT(*) FILTER (WHERE order_id IS NULL) AS missing_order_ids,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS missing_customer_ids,
    COUNT(*) FILTER (WHERE store_id IS NULL) AS missing_store_ids,
    COUNT(*) FILTER (WHERE order_timestamp IS NULL) AS missing_order_timestamps
FROM orders_clean;

SELECT 
    COUNT(order_status),
    order_status
FROM orders_clean
WHERE order_timestamp IS NULL
GROUP BY order_status;

SELECT
    COUNT(*) FILTER (WHERE order_status IS NULL) AS missing_order_status,
    COUNT(*) FILTER (WHERE gross_merchandise_value_inr IS NULL) AS missing_gmv,
    COUNT(*) FILTER (WHERE net_revenue_inr IS NULL) AS missing_net_revenue,
    COUNT(*) FILTER (WHERE gross_profit_inr IS NULL) AS missing_gross_profit
FROM orders_clean;

SELECT
    COUNT(*) FILTER (WHERE order_item_id IS NULL) AS missing_order_item_ids,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS missing_order_ids,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS missing_product_ids,
    COUNT(*) FILTER (WHERE quantity IS NULL) AS missing_quantities
FROM order_items_clean;


SELECT
    COUNT(*) FILTER (WHERE delivery_id IS NULL) AS missing_delivery_ids,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS missing_order_ids,
    COUNT(*) FILTER (WHERE rider_id IS NULL) AS missing_rider_ids,
    COUNT(*) FILTER (WHERE accepted_timestamp IS NULL) AS missing_accepted_timestamps,
    COUNT(*) FILTER (WHERE delivered_timestamp IS NULL) AS missing_delivered_timestamps,
    COUNT(*) FILTER (WHERE actual_delivery_minutes IS NULL) AS missing_delivery_minutes
FROM deliveries;


SELECT * FROM deliveries WHERE delivered_timestamp IS NULL;


SELECT
    o.order_status,
    COUNT(*) AS missing_timestamps
FROM deliveries d
LEFT JOIN orders_clean o
    ON d.order_id = o.order_id
WHERE d.delivered_timestamp IS NULL
GROUP BY o.order_status
ORDER BY missing_timestamps DESC;

SELECT
    COUNT(*) FILTER (WHERE inventory_record_id IS NULL) AS missing_inventory_ids,
    COUNT(*) FILTER (WHERE date IS NULL) AS missing_dates,
    COUNT(*) FILTER (WHERE store_id IS NULL) AS missing_store_ids,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS missing_product_ids,
    COUNT(*) FILTER (WHERE closing_stock_units IS NULL) AS missing_closing_stock,
    COUNT(*) FILTER (WHERE wastage_cost_inr IS NULL) AS missing_wastage_cost
FROM inventory_clean;

SELECT
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS missing_customer_ids,
    COUNT(*) FILTER (WHERE signup_date IS NULL) AS missing_signup_dates,
    COUNT(*) FILTER (WHERE customer_segment IS NULL) AS missing_customer_segments
FROM customers;

SELECT
    COUNT(*) FILTER (WHERE product_id IS NULL) AS missing_product_ids,
    COUNT(*) FILTER (WHERE category IS NULL) AS missing_categories,
    COUNT(*) FILTER (WHERE list_price_inr IS NULL) AS missing_list_prices,
    COUNT(*) FILTER (WHERE unit_cost_inr IS NULL) AS missing_unit_costs
FROM products;

SELECT
    'stores' AS table_name,
    COUNT(*) FILTER (WHERE store_id IS NULL)
    + COUNT(*) FILTER (WHERE zone IS NULL)
    + COUNT(*) FILTER (WHERE status IS NULL) AS total_missing_values
FROM stores

UNION ALL

SELECT
    'riders',
    COUNT(*) FILTER (WHERE rider_id IS NULL)
    + COUNT(*) FILTER (WHERE base_zone IS NULL)
    + COUNT(*) FILTER (WHERE status IS NULL)
FROM riders

UNION ALL

SELECT
    'promotions',
    COUNT(*) FILTER (WHERE promo_id IS NULL)
    + COUNT(*) FILTER (WHERE start_date IS NULL)
    + COUNT(*) FILTER (WHERE end_date IS NULL)
FROM promotions

UNION ALL

SELECT
    'promotion_exposures',
    COUNT(*) FILTER (WHERE exposure_id IS NULL)
    + COUNT(*) FILTER (WHERE promo_id IS NULL)
    + COUNT(*) FILTER (WHERE customer_id IS NULL)
    + COUNT(*) FILTER (WHERE assignment_group IS NULL)
FROM promotion_exposures

UNION ALL

SELECT
    'external_factors',
    COUNT(*) FILTER (WHERE date IS NULL)
    + COUNT(*) FILTER (WHERE zone IS NULL)
    + COUNT(*) FILTER (WHERE traffic_index IS NULL)
    + COUNT(*) FILTER (WHERE rainfall_mm IS NULL)
FROM external_factors;



/*DATA CONSISTENCY check*/

SELECT 
    COUNT(*) FILTER(WHERE gross_merchandise_value_inr < 0) AS negative_gmv,
    COUNT(*) FILTER(WHERE net_revenue_inr < 0) AS negative_nr,
    COUNT(*) FILTER(WHERE delivery_distance_km < 0) AS negative_dd,
    COUNT(*) FILTER(WHERE promised_delivery_minutes <= 0) AS zero_or_below_pdm
FROM orders_clean;

SELECT 
    COUNT(*) FILTER(WHERE promised_delivery_minutes = 0) AS zero_or_below_pdm
FROM orders_clean;

SELECT 
    COUNT(*)
FROM orders_clean
WHERE promised_delivery_minutes = 0 AND order_status = 'Completed';

SELECT
    order_status,
    promised_delivery_minutes,
    COUNT(*) AS number_of_orders
FROM orders_clean
WHERE promised_delivery_minutes <= 0
GROUP BY order_status, promised_delivery_minutes
ORDER BY order_status, promised_delivery_minutes;


SELECT
    COUNT(*) FILTER (WHERE requested_quantity <= 0) AS invalid_requested_quantity,
    COUNT(*) FILTER (WHERE quantity < 0) AS negative_quantity,
    COUNT(*) FILTER (WHERE quantity > requested_quantity) AS excess_quantity,
    COUNT(*) FILTER (WHERE unit_price_inr < 0) AS negative_unit_price
FROM order_items_clean;

SELECT
    COUNT(*) FILTER (WHERE opening_stock_units < 0) AS negative_opening_stock,
    COUNT(*) FILTER (WHERE closing_stock_units < 0) AS negative_closing_stock,
    COUNT(*) FILTER (WHERE sold_units < 0) AS negative_sold_units,
    COUNT(*) FILTER (WHERE stockout_minutes < 0 OR stockout_minutes > 1440) AS invalid_stockout_minutes
FROM inventory_clean;

SELECT
    COUNT(*) FILTER (WHERE actual_delivery_minutes <= 0) AS invalid_delivery_duration,
    COUNT(*) FILTER (WHERE assignment_wait_minutes < 0) AS negative_assignment_wait,
    COUNT(*) FILTER (WHERE preparation_minutes < 0) AS negative_preparation_time,
    COUNT(*) FILTER (WHERE delivered_timestamp < accepted_timestamp) AS invalid_timestamp_order
FROM deliveries;

SELECT
    COUNT(*) FILTER (WHERE list_price_inr <= 0) AS invalid_list_price,
    COUNT(*) FILTER (WHERE unit_cost_inr < 0) AS negative_unit_cost,
    COUNT(*) FILTER (WHERE shelf_life_days <= 0) AS invalid_shelf_life
FROM products;

SELECT
    COUNT(*) FILTER (WHERE end_date < start_date) AS invalid_promotion_dates,
    COUNT(*) FILTER (WHERE discount_value < 0) AS negative_discount
FROM promotions;

SELECT
    COUNT(*) FILTER (WHERE rainfall_mm < 0) AS negative_rainfall,
    COUNT(*) FILTER (WHERE traffic_index < 0) AS negative_traffic_index,
    COUNT(*) FILTER (
        WHERE temperature_c < -50 OR temperature_c > 60
    ) AS invalid_temperature
FROM external_factors;

SELECT
    store_id,
    store_name,
    TRIM(store_name) AS trimmed_name,
    INITCAP(TRIM(store_name)) AS standardised_name
FROM stores
ORDER BY store_id;

CREATE TABLE stores_clean AS
SELECT
    store_id,
    CASE
        WHEN store_id IN ('S001', 'S005')
            THEN INITCAP(TRIM(store_name))
        ELSE store_name
    END AS store_name,
    zone,
    neighborhood,
    latitude,
    longitude,
    opening_date,
    area_sq_ft,
    daily_capacity_orders,
    customer_rating,
    status
FROM stores;

SELECT
    store_id,
    store_name,
    row_number() OVER(ORDER BY store_id) AS store_number
FROM stores_clean
ORDER BY store_id;

SELECT
    COUNT(*) AS invalid_customer_references
FROM orders_clean o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

SELECT
    COUNT(*) AS invalid_store_references
FROM orders_clean o
LEFT JOIN stores_clean s
    ON o.store_id = s.store_id
WHERE s.store_id IS NULL;


-- 1. Order items referencing nonexistent orders
SELECT
    'order_items → orders' AS relationship,
    COUNT(*) AS invalid_references
FROM order_items_clean oi
LEFT JOIN orders_clean o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL

-- 2. Order items referencing nonexistent products
SELECT
    'order_items → products',
    COUNT(*)
FROM order_items_clean oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL

UNION ALL

-- 3. Deliveries referencing nonexistent orders
SELECT
    'deliveries → orders',
    COUNT(*)
FROM deliveries d
LEFT JOIN orders_clean o
    ON d.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL

-- 4. Deliveries referencing nonexistent riders
SELECT
    'deliveries → riders',
    COUNT(*)
FROM deliveries d
LEFT JOIN riders r
    ON d.rider_id = r.rider_id
WHERE r.rider_id IS NULL;
/*-----*/

-- 1. Inventory → Stores
SELECT
    'inventory → stores' AS relationship,
    COUNT(*) AS invalid_references
FROM inventory_clean i
LEFT JOIN stores_clean s
    ON i.store_id = s.store_id
WHERE s.store_id IS NULL

UNION ALL

-- 2. Inventory → Products
SELECT
    'inventory → products',
    COUNT(*)
FROM inventory_clean i
LEFT JOIN products p
    ON i.product_id = p.product_id
WHERE p.product_id IS NULL

UNION ALL

-- 3. Promotion Exposures → Promotions
SELECT
    'promotion_exposures → promotions',
    COUNT(*)
FROM promotion_exposures pe
LEFT JOIN promotions p
    ON pe.promo_id = p.promo_id
WHERE p.promo_id IS NULL

UNION ALL

-- 4. Promotion Exposures → Customers
SELECT
    'promotion_exposures → customers',
    COUNT(*)
FROM promotion_exposures pe
LEFT JOIN customers c
    ON pe.customer_id = c.customer_id
WHERE c.customer_id IS NULL

UNION ALL

-- 5. Orders → Promotions
SELECT
    'orders → promotions',
    COUNT(*)
FROM orders_clean o
LEFT JOIN promotions p
    ON o.promo_id = p.promo_id
WHERE p.promo_id IS NULL
  AND o.promo_id IS NOT NULL;

  SELECT
    order_id,
    COUNT(*) AS delivery_count
FROM deliveries
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY delivery_count DESC
LIMIT 10;

SELECT
    date,
    store_id,
    product_id,
    COUNT(*) AS record_count
FROM inventory_clean
GROUP BY date, store_id, product_id
HAVING COUNT(*) > 1
ORDER BY record_count DESC
LIMIT 10;

ALTER TABLE orders_clean
ADD CONSTRAINT pk_orders_clean
PRIMARY KEY (order_id);

SELECT
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'orders_clean'
  AND constraint_type = 'PRIMARY KEY';

-- 1. Order Items
ALTER TABLE order_items_clean
ADD CONSTRAINT pk_order_items_clean
PRIMARY KEY (order_item_id);

-- 2. Inventory
ALTER TABLE inventory_clean
ADD CONSTRAINT pk_inventory_clean
PRIMARY KEY (inventory_record_id);

-- 3. Deliveries
ALTER TABLE deliveries
ADD CONSTRAINT pk_deliveries
PRIMARY KEY (delivery_id);

-- 4. Customers
ALTER TABLE customers
ADD CONSTRAINT pk_customers
PRIMARY KEY (customer_id);

-- 5. Products
ALTER TABLE products
ADD CONSTRAINT pk_products
PRIMARY KEY (product_id);

-- 6. Stores
ALTER TABLE stores_clean
ADD CONSTRAINT pk_stores_clean
PRIMARY KEY (store_id);

-- 7. Riders
ALTER TABLE riders
ADD CONSTRAINT pk_riders
PRIMARY KEY (rider_id);

-- 8. Promotions
ALTER TABLE promotions
ADD CONSTRAINT pk_promotions
PRIMARY KEY (promo_id);

-- 9. Promotion Exposures
ALTER TABLE promotion_exposures
ADD CONSTRAINT pk_promotion_exposures
PRIMARY KEY (exposure_id);

-- 10. External Factors (Composite Primary Key)
ALTER TABLE external_factors
ADD CONSTRAINT pk_external_factors
PRIMARY KEY (date, zone);


SELECT
    table_name,
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'public'
  AND constraint_type = 'PRIMARY KEY'
  ORDER BY table_name;


-- 1. Orders → Customers
ALTER TABLE orders_clean
ADD CONSTRAINT fk_orders_customers
FOREIGN KEY (customer_id)
REFERENCES customers(customer_id);

-- 2. Orders → Stores
ALTER TABLE orders_clean
ADD CONSTRAINT fk_orders_stores
FOREIGN KEY (store_id)
REFERENCES stores_clean(store_id);

-- 3. Orders → Promotions
ALTER TABLE orders_clean
ADD CONSTRAINT fk_orders_promotions
FOREIGN KEY (promo_id)
REFERENCES promotions(promo_id);

-- 4. Order Items → Orders
ALTER TABLE order_items_clean
ADD CONSTRAINT fk_order_items_orders
FOREIGN KEY (order_id)
REFERENCES orders_clean(order_id);

-- 5. Order Items → Products
ALTER TABLE order_items_clean
ADD CONSTRAINT fk_order_items_products
FOREIGN KEY (product_id)
REFERENCES products(product_id);

-- 6. Deliveries → Orders
ALTER TABLE deliveries
ADD CONSTRAINT fk_deliveries_orders
FOREIGN KEY (order_id)
REFERENCES orders_clean(order_id);

-- 7. Deliveries → Riders
ALTER TABLE deliveries
ADD CONSTRAINT fk_deliveries_riders
FOREIGN KEY (rider_id)
REFERENCES riders(rider_id);

-- 8. Inventory → Stores
ALTER TABLE inventory_clean
ADD CONSTRAINT fk_inventory_stores
FOREIGN KEY (store_id)
REFERENCES stores_clean(store_id);

-- 9. Inventory → Products
ALTER TABLE inventory_clean
ADD CONSTRAINT fk_inventory_products
FOREIGN KEY (product_id)
REFERENCES products(product_id);

-- 10. Promotion Exposures → Promotions
ALTER TABLE promotion_exposures
ADD CONSTRAINT fk_exposures_promotions
FOREIGN KEY (promo_id)
REFERENCES promotions(promo_id);

-- 11. Promotion Exposures → Customers
ALTER TABLE promotion_exposures
ADD CONSTRAINT fk_exposures_customers
FOREIGN KEY (customer_id)
REFERENCES customers(customer_id);


SELECT
    table_name,
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'public'
  AND constraint_type = 'FOREIGN KEY'
  ORDER BY table_name;