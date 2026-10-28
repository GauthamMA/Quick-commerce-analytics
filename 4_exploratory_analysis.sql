--Business Question 1 of 8: When and where do order volumes peak?


SELECT * FROM orders_clean LIMIT 10;

SELECT
    o.store_id,
    s.store_name,
    COUNT(o.order_id) AS number_of_orders
FROM orders_clean o
LEFT JOIN stores_clean s ON o.store_id = s.store_id
GROUP BY o.store_id,s.store_name
ORDER BY number_of_orders DESC; 

SELECT
    COUNT(order_id) AS number_of_orders,
    EXTRACT(HOUR FROM order_timestamp) as order_hour
FROM orders_clean
WHERE order_timestamp IS NOT NULL
GROUP BY EXTRACT(HOUR FROM order_timestamp)
ORDER BY order_hour;

SELECT
    COUNT(o.order_id) AS total_orders,
    EXTRACT(HOUR FROM o.order_timestamp) as order_hour,
    o.store_id,
    s.store_name
FROM orders_clean o
INNER JOIN stores_clean s ON o.store_id = s.store_id
WHERE o.order_timestamp IS NOT NULL
GROUP BY s.store_name,o.store_id,EXTRACT(HOUR FROM o.order_timestamp) 
ORDER BY total_orders DESC
LIMIT 5 ;

SELECT
    TRIM(TO_CHAR(order_timestamp, 'Day')) AS day_of_week,
    COUNT(*) AS total_orders
FROM orders_clean
WHERE order_timestamp IS NOT NULL
GROUP BY
    EXTRACT(ISODOW FROM order_timestamp),
    TO_CHAR(order_timestamp, 'Day')
ORDER BY
    EXTRACT(ISODOW FROM order_timestamp);

/*Which products frequently go out of stock?*/


SELECT * FROM inventory_clean LIMIT 10;


SELECT
    i.product_id,
    p.product_name,
    p.category,
    COUNT(*) AS stockout_store_days
FROM inventory_clean i
INNER JOIN products p
    ON i.product_id = p.product_id
WHERE i.stockout_minutes > 0
GROUP BY
    i.product_id,
    p.product_name,
    p.category
ORDER BY stockout_store_days DESC
LIMIT 10;





-- Business Question 2: Which products frequently go out of stock?
-- Calculate stockout frequency as a percentage of observed store-days.

SELECT
    i.product_id,
    p.product_name,
    COUNT(*) AS total_store_days,
    COUNT(*) FILTER (
        WHERE i.stockout_minutes > 0
    ) AS stockout_store_days,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE i.stockout_minutes > 0
        ) / COUNT(*),
        2
    ) AS stockout_rate_pct
FROM inventory_clean i
INNER JOIN products p
    ON i.product_id = p.product_id
GROUP BY
    i.product_id,
    p.product_name
ORDER BY stockout_rate_pct DESC
LIMIT 10;


-- Business Question 2: Product stockout frequency and rates
-- Create a reusable view for Power BI reporting.

CREATE OR REPLACE VIEW vw_product_stockouts AS

SELECT
    i.product_id,
    p.product_name,
    COUNT(*) AS total_store_days,
    COUNT(*) FILTER (
        WHERE i.stockout_minutes > 0
    ) AS stockout_store_days,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE i.stockout_minutes > 0
        ) / COUNT(*),
        2
    ) AS stockout_rate_pct
FROM inventory_clean i
INNER JOIN products p
    ON i.product_id = p.product_id
GROUP BY
    i.product_id,
    p.product_name;

SELECT * FROM vw_product_stockouts;


Business Question 3 of 8
Which products are overstocked or wasted?


-- Business Question 3: Which products are overstocked or wasted?
-- Identify the 10 products with the highest total wastage cost.

SELECT
    i.product_id,
    p.product_name,
    p.category,
    ROUND(SUM(i.wastage_cost_inr), 2) AS total_wastage_cost_inr
FROM inventory_clean i
INNER JOIN products p
    ON i.product_id = p.product_id
GROUP BY
    i.product_id,
    p.product_name,
    p.category
ORDER BY total_wastage_cost_inr DESC
LIMIT 10;



CREATE OR REPLACE VIEW vw_product_wastage AS
SELECT
    i.product_id,
    p.product_name,
    p.category,
    ROUND(SUM(i.wastage_cost_inr), 2) AS total_wastage_cost_inr
FROM inventory_clean i
INNER JOIN products p
    ON i.product_id = p.product_id
GROUP BY
    i.product_id,
    p.product_name,
    p.category;


-- Inspect available inventory fields
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'inventory_clean'
ORDER BY ordinal_position;

SELECT *
FROM inventory_clean
LIMIT 5;



-- Business Question 3: Which products are overstocked?
-- Calculate days of stock cover using the latest closing stock
-- and average daily sales over the preceding 28 days.

WITH recent_sales AS (
    SELECT
        store_id,
        product_id,
        AVG(sold_units::NUMERIC) AS avg_daily_units_sold
    FROM inventory_clean
    WHERE date BETWEEN
        (SELECT MAX(date) FROM inventory_clean) - 27
        AND (SELECT MAX(date) FROM inventory_clean)
    GROUP BY
        store_id,
        product_id
),

latest_stock AS (
    SELECT
        store_id,
        product_id,
        closing_stock_units
    FROM inventory_clean
    WHERE date = (SELECT MAX(date) FROM inventory_clean)
)

SELECT
    s.store_id,
    s.product_id,
    p.product_name,
    s.closing_stock_units,
    r.avg_daily_units_sold,
    ROUND(
        s.closing_stock_units::NUMERIC /
        NULLIF(r.avg_daily_units_sold, 0),
        2
    ) AS days_of_stock_cover
FROM latest_stock s
INNER JOIN recent_sales r
    ON s.store_id = r.store_id
    AND s.product_id = r.product_id
INNER JOIN products p
    ON s.product_id = p.product_id
WHERE r.avg_daily_units_sold > 0
ORDER BY days_of_stock_cover DESC
LIMIT 10;


Next — Business Question 4 of 8
What factors cause late deliveries?

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'deliveries'
ORDER BY ordinal_position;

SELECT *
FROM deliveries
LIMIT 5;


-- Business Question 4: What factors cause late deliveries?
-- Establish the overall delivery performance baseline.

SELECT
    COUNT(*) AS total_deliveries,

    COUNT(*) FILTER (
        WHERE is_late IS TRUE
    ) AS late_deliveries,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE is_late IS TRUE
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_rate_pct,

    ROUND(
        AVG(actual_delivery_minutes),
        2
    ) AS avg_delivery_minutes,

    ROUND(
        AVG(promised_delivery_minutes),
        2
    ) AS avg_promised_minutes

FROM deliveries
WHERE promised_delivery_minutes > 0
  AND actual_delivery_minutes IS NOT NULL;


-- Business Question 4: What factors are associated with late deliveries?
-- Compare average time spent at each delivery stage.

SELECT
    is_late,
    COUNT(*) AS total_deliveries,

    ROUND(
        AVG(assignment_wait_minutes), 2
    ) AS avg_assignment_wait,

    ROUND(
        AVG(preparation_minutes), 2
    ) AS avg_preparation,

    ROUND(
        AVG(travel_minutes), 2
    ) AS avg_travel,

    ROUND(
        AVG(handoff_minutes), 2
    ) AS avg_handoff

FROM deliveries
WHERE promised_delivery_minutes > 0
  AND actual_delivery_minutes IS NOT NULL

GROUP BY is_late
ORDER BY is_late;

-- Business Question 4: What factors are associated with late deliveries?
-- Compare distance, traffic, rainfall, and promised delivery time
-- between late and on-time deliveries.

SELECT
    is_late,
    COUNT(*) AS total_deliveries,

    ROUND(
        AVG(distance_km), 2
    ) AS avg_distance_km,

    ROUND(
        AVG(traffic_index), 2
    ) AS avg_traffic_index,

    ROUND(
        AVG(rainfall_mm), 2
    ) AS avg_rainfall_mm,

    ROUND(
        AVG(promised_delivery_minutes), 2
    ) AS avg_promised_minutes

FROM deliveries
WHERE promised_delivery_minutes > 0
  AND actual_delivery_minutes IS NOT NULL

GROUP BY is_late
ORDER BY is_late;


-- Business Question 4: What factors are associated with late deliveries?
-- Compare late delivery rates across different traffic conditions.

WITH traffic_groups AS (
    SELECT
        CASE
            WHEN traffic_index < 50 THEN 'Low'
            WHEN traffic_index < 70 THEN 'Moderate'
            ELSE 'High'
        END AS traffic_level,
        is_late
    FROM deliveries
    WHERE promised_delivery_minutes > 0
      AND actual_delivery_minutes IS NOT NULL
      AND traffic_index IS NOT NULL
)

SELECT
    traffic_level,
    COUNT(*) AS total_deliveries,

    COUNT(*) FILTER (
        WHERE is_late IS TRUE
    ) AS late_deliveries,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE is_late IS TRUE
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_rate_pct

FROM traffic_groups
GROUP BY traffic_level

ORDER BY
    CASE traffic_level
        WHEN 'Low' THEN 1
        WHEN 'Moderate' THEN 2
        WHEN 'High' THEN 3
    END;

-- Business Question 4: Late delivery rates by traffic level
-- Create a reusable view for Power BI.

CREATE OR REPLACE VIEW vw_delivery_traffic_lateness AS

WITH traffic_groups AS (
    SELECT
        CASE
            WHEN traffic_index < 50 THEN 'Low'
            WHEN traffic_index < 70 THEN 'Moderate'
            ELSE 'High'
        END AS traffic_level,
        is_late
    FROM deliveries
    WHERE promised_delivery_minutes > 0
      AND actual_delivery_minutes IS NOT NULL
      AND traffic_index IS NOT NULL
)

SELECT
    traffic_level,

    COUNT(*) AS total_deliveries,

    COUNT(*) FILTER (
        WHERE is_late IS TRUE
    ) AS late_deliveries,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE is_late IS TRUE
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_rate_pct

FROM traffic_groups
GROUP BY traffic_level;


SELECT *
FROM vw_delivery_traffic_lateness
ORDER BY
    CASE traffic_level
        WHEN 'Low' THEN 1
        WHEN 'Moderate' THEN 2
        WHEN 'High' THEN 3
    END;

Next — Business Question 5 of 8
How many delivery partners are required by store and hour?

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'riders'
ORDER BY ordinal_position;

SELECT *
FROM riders
LIMIT 5;


-- Business Question 5: How many delivery partners are required
-- by store and hour?
-- Identify the 10 busiest store-hour combinations based on
-- average daily delivery demand during 2025.

SELECT
    d.store_id,

    EXTRACT(HOUR FROM o.order_timestamp) AS order_hour,

    COUNT(d.delivery_id) AS total_deliveries,

    ROUND(
        COUNT(d.delivery_id) / 365.0,
        2
    ) AS avg_daily_deliveries

FROM deliveries d
INNER JOIN orders_clean o
    ON d.order_id = o.order_id

WHERE o.order_timestamp IS NOT NULL

GROUP BY
    d.store_id,
    EXTRACT(HOUR FROM o.order_timestamp)

ORDER BY avg_daily_deliveries DESC
LIMIT 10;

-- Business Question 5: How many delivery partners are required
-- by store and hour?
-- Assumptions:
-- 2 deliveries per rider per hour
-- 80% planned utilization
-- Effective capacity = 1.6 deliveries per rider-hour

WITH hourly_demand AS (
    SELECT
        d.store_id,
        EXTRACT(HOUR FROM o.order_timestamp)::INT AS order_hour,
        COUNT(d.delivery_id) AS total_deliveries,

        COUNT(d.delivery_id) / 365.0 AS avg_daily_deliveries

    FROM deliveries d
    INNER JOIN orders_clean o
        ON d.order_id = o.order_id

    WHERE o.order_timestamp IS NOT NULL

    GROUP BY
        d.store_id,
        EXTRACT(HOUR FROM o.order_timestamp)
)

SELECT
    store_id,
    order_hour,
    total_deliveries,

    ROUND(
        avg_daily_deliveries, 2
    ) AS avg_daily_deliveries,

    CEIL(
        avg_daily_deliveries / 1.6
    )::INT AS estimated_riders_required

FROM hourly_demand

ORDER BY
    store_id,
    order_hour;

-- Business Question 5: Estimated delivery partners required by store and hour
-- Assumptions:
-- 2 deliveries per rider-hour
-- 80% planned utilization
-- Effective capacity = 1.6 deliveries per rider-hour

CREATE OR REPLACE VIEW vw_hourly_rider_requirements AS

WITH hourly_demand AS (
    SELECT
        d.store_id,
        EXTRACT(HOUR FROM o.order_timestamp)::INT AS order_hour,
        COUNT(d.delivery_id) AS total_deliveries,
        COUNT(d.delivery_id) / 365.0 AS avg_daily_deliveries

    FROM deliveries d
    INNER JOIN orders_clean o
        ON d.order_id = o.order_id

    WHERE o.order_timestamp IS NOT NULL

    GROUP BY
        d.store_id,
        EXTRACT(HOUR FROM o.order_timestamp)
)

SELECT
    store_id,
    order_hour,
    total_deliveries,

    ROUND(
        avg_daily_deliveries, 2
    ) AS avg_daily_deliveries,

    CEIL(
        avg_daily_deliveries / 1.6
    )::INT AS estimated_riders_required

FROM hourly_demand;

SELECT COUNT(*)
FROM vw_hourly_rider_requirements;

Next — Business Question 6 of 8
Which discounts generate incremental demand?

SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('promotions', 'promotion_exposures')
ORDER BY table_name, ordinal_position;

SELECT *
FROM promotions
LIMIT 5;

SELECT *
FROM promotion_exposures
LIMIT 5;

-- Business Question 6: Check treatment and control group sizes

SELECT
    e.promo_id,
    p.promo_code,
    p.campaign_type,
    e.assignment_group,
    COUNT(DISTINCT e.customer_id) AS assigned_customers
FROM promotion_exposures e
INNER JOIN promotions p
    ON e.promo_id = p.promo_id
GROUP BY
    e.promo_id,
    p.promo_code,
    p.campaign_type,
    e.assignment_group
ORDER BY
    e.promo_id,
    e.assignment_group;

-- Business Question 6: Which discounts generate incremental demand?
-- Compare purchasing behaviour between treatment and control groups.
-- A customer counts as converted if they place at least one
-- completed order during their eligible campaign period.

CREATE INDEX IF NOT EXISTS idx_orders_customer_completed_date
ON orders_clean (customer_id, order_timestamp)
WHERE order_status = 'Completed';



WITH customer_conversions AS (
    SELECT
        e.promo_id,
        e.assignment_group,
        e.customer_id,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM orders_clean o
                WHERE o.customer_id = e.customer_id
                  AND o.order_status = 'Completed'
                  AND o.order_timestamp >= e.assigned_date
                  AND o.order_timestamp < p.end_date + INTERVAL '1 day'
            )
            THEN 1
            ELSE 0
        END AS converted

    FROM promotion_exposures e
    INNER JOIN promotions p
        ON e.promo_id = p.promo_id
)

SELECT
    promo_id,
    assignment_group,

    COUNT(DISTINCT customer_id) AS assigned_customers,

    COUNT(DISTINCT customer_id) FILTER (
        WHERE converted = 1
    ) AS purchasing_customers,

    ROUND(
        100.0 * COUNT(DISTINCT customer_id) FILTER (
            WHERE converted = 1
        ) / NULLIF(COUNT(DISTINCT customer_id), 0),
        2
    ) AS conversion_rate_pct

FROM customer_conversions

GROUP BY
    promo_id,
    assignment_group

ORDER BY
    promo_id,
    assignment_group;

-- Business Question 6: Which discounts generate incremental demand?
-- Compare treatment and control conversion rates for each promotion.
-- Rank promotions by conversion uplift in percentage points.

WITH customer_conversions AS (
    SELECT
        e.promo_id,
        e.assignment_group,
        e.customer_id,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM orders_clean o
                WHERE o.customer_id = e.customer_id
                  AND o.order_status = 'Completed'
                  AND o.order_timestamp >= e.assigned_date
                  AND o.order_timestamp < p.end_date + INTERVAL '1 day'
            )
            THEN 1
            ELSE 0
        END AS converted

    FROM promotion_exposures e
    INNER JOIN promotions p
        ON e.promo_id = p.promo_id
),

group_results AS (
    SELECT
        promo_id,
        assignment_group,
        COUNT(DISTINCT customer_id) AS assigned_customers,
        COUNT(DISTINCT customer_id) FILTER (
            WHERE converted = 1
        ) AS purchasing_customers

    FROM customer_conversions
    GROUP BY promo_id, assignment_group
),

promotion_comparison AS (
    SELECT
        promo_id,

        MAX(assigned_customers) FILTER (
            WHERE assignment_group = 'Control'
        ) AS control_customers,

        MAX(purchasing_customers) FILTER (
            WHERE assignment_group = 'Control'
        ) AS control_purchasers,

        MAX(assigned_customers) FILTER (
            WHERE assignment_group = 'Treatment'
        ) AS treatment_customers,

        MAX(purchasing_customers) FILTER (
            WHERE assignment_group = 'Treatment'
        ) AS treatment_purchasers

    FROM group_results
    GROUP BY promo_id
)

SELECT
    c.promo_id,
    p.campaign_type,
    p.discount_type,
    p.discount_value,

    ROUND(
        100.0 * c.control_purchasers /
        NULLIF(c.control_customers, 0),
        2
    ) AS control_conversion_pct,

    ROUND(
        100.0 * c.treatment_purchasers /
        NULLIF(c.treatment_customers, 0),
        2
    ) AS treatment_conversion_pct,

    ROUND(
        100.0 * (
            c.treatment_purchasers::NUMERIC /
            NULLIF(c.treatment_customers, 0)
            -
            c.control_purchasers::NUMERIC /
            NULLIF(c.control_customers, 0)
        ),
        2
    ) AS uplift_pp

FROM promotion_comparison c
INNER JOIN promotions p
    ON c.promo_id = p.promo_id

ORDER BY uplift_pp DESC;


SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'orders_clean'
ORDER BY ordinal_position;

-- Business Question 6: Which promotions generate incremental demand?
-- Compare gross profit per assigned customer between
-- Treatment and Control groups.
-- Include customers who made no purchases (₹0 gross profit).

WITH customer_profit AS (
    SELECT
        e.promo_id,
        e.assignment_group,
        e.customer_id,

        COALESCE(
            (
                SELECT SUM(o.gross_profit_inr)
                FROM orders_clean o
                WHERE o.customer_id = e.customer_id
                  AND o.order_status = 'Completed'
                  AND o.order_timestamp >= e.assigned_date
                  AND o.order_timestamp < p.end_date + INTERVAL '1 day'
            ),
            0
        ) AS customer_gross_profit_inr

    FROM promotion_exposures e
    INNER JOIN promotions p
        ON e.promo_id = p.promo_id
)

SELECT
    promo_id,
    assignment_group,

    COUNT(DISTINCT customer_id) AS assigned_customers,

    ROUND(
        SUM(customer_gross_profit_inr), 2
    ) AS total_gross_profit_inr,

    ROUND(
        SUM(customer_gross_profit_inr) /
        NULLIF(COUNT(DISTINCT customer_id), 0),
        2
    ) AS gross_profit_per_customer_inr

FROM customer_profit

GROUP BY
    promo_id,
    assignment_group

ORDER BY
    promo_id,
    assignment_group;

-- Business Question 6: Which discounts generate incremental demand?
-- Compare conversion uplift and gross profit uplift for each promotion.
-- Include all completed orders within the customer's campaign window,
-- whether or not a promotion code was used.

WITH group_results AS (
    SELECT
        e.promo_id,
        e.assignment_group,

        COUNT(DISTINCT e.customer_id) AS assigned_customers,

        COUNT(DISTINCT o.customer_id) AS purchasing_customers,

        COALESCE(
            SUM(o.gross_profit_inr), 0
        ) AS total_gross_profit_inr

    FROM promotion_exposures e

    INNER JOIN promotions p
        ON e.promo_id = p.promo_id

    LEFT JOIN orders_clean o
        ON e.customer_id = o.customer_id
        AND o.order_status = 'Completed'
        AND o.order_timestamp >= e.assigned_date
        AND o.order_timestamp < p.end_date + INTERVAL '1 day'

    GROUP BY
        e.promo_id,
        e.assignment_group
),

promotion_comparison AS (
    SELECT
        promo_id,

        MAX(assigned_customers) FILTER (
            WHERE assignment_group = 'Control'
        ) AS control_customers,

        MAX(purchasing_customers) FILTER (
            WHERE assignment_group = 'Control'
        ) AS control_purchasers,

        MAX(total_gross_profit_inr) FILTER (
            WHERE assignment_group = 'Control'
        ) AS control_gross_profit,

        MAX(assigned_customers) FILTER (
            WHERE assignment_group = 'Treatment'
        ) AS treatment_customers,

        MAX(purchasing_customers) FILTER (
            WHERE assignment_group = 'Treatment'
        ) AS treatment_purchasers,

        MAX(total_gross_profit_inr) FILTER (
            WHERE assignment_group = 'Treatment'
        ) AS treatment_gross_profit

    FROM group_results
    GROUP BY promo_id
)

SELECT
    c.promo_id,
    p.campaign_type,
    p.discount_type,
    p.discount_value,

    ROUND(
        100.0 * (
            c.treatment_purchasers::NUMERIC /
                NULLIF(c.treatment_customers, 0)
            -
            c.control_purchasers::NUMERIC /
                NULLIF(c.control_customers, 0)
        ),
        2
    ) AS conversion_uplift_pp,

    ROUND(
        c.treatment_gross_profit /
            NULLIF(c.treatment_customers, 0)
        -
        c.control_gross_profit /
            NULLIF(c.control_customers, 0),
        2
    ) AS gp_uplift_per_customer_inr

FROM promotion_comparison c

INNER JOIN promotions p
    ON c.promo_id = p.promo_id

ORDER BY gp_uplift_per_customer_inr DESC;




CREATE OR REPLACE VIEW vw_promotion_performance AS



WITH group_results AS (
    SELECT
        e.promo_id,
        e.assignment_group,

        COUNT(DISTINCT e.customer_id) AS assigned_customers,

        COUNT(DISTINCT o.customer_id) AS purchasing_customers,

        COALESCE(
            SUM(o.gross_profit_inr), 0
        ) AS total_gross_profit_inr

    FROM promotion_exposures e

    INNER JOIN promotions p
        ON e.promo_id = p.promo_id

    LEFT JOIN orders_clean o
        ON e.customer_id = o.customer_id
        AND o.order_status = 'Completed'
        AND o.order_timestamp >= e.assigned_date
        AND o.order_timestamp < p.end_date + INTERVAL '1 day'

    GROUP BY
        e.promo_id,
        e.assignment_group
),

promotion_comparison AS (
    SELECT
        promo_id,

        MAX(assigned_customers) FILTER (
            WHERE assignment_group = 'Control'
        ) AS control_customers,

        MAX(purchasing_customers) FILTER (
            WHERE assignment_group = 'Control'
        ) AS control_purchasers,

        MAX(total_gross_profit_inr) FILTER (
            WHERE assignment_group = 'Control'
        ) AS control_gross_profit,

        MAX(assigned_customers) FILTER (
            WHERE assignment_group = 'Treatment'
        ) AS treatment_customers,

        MAX(purchasing_customers) FILTER (
            WHERE assignment_group = 'Treatment'
        ) AS treatment_purchasers,

        MAX(total_gross_profit_inr) FILTER (
            WHERE assignment_group = 'Treatment'
        ) AS treatment_gross_profit

    FROM group_results
    GROUP BY promo_id
)

SELECT
    c.promo_id,
    p.campaign_type,
    p.discount_type,
    p.discount_value,

    ROUND(
        100.0 * (
            c.treatment_purchasers::NUMERIC /
                NULLIF(c.treatment_customers, 0)
            -
            c.control_purchasers::NUMERIC /
                NULLIF(c.control_customers, 0)
        ),
        2
    ) AS conversion_uplift_pp,

    ROUND(
        c.treatment_gross_profit /
            NULLIF(c.treatment_customers, 0)
        -
        c.control_gross_profit /
            NULLIF(c.control_customers, 0),
        2
    ) AS gp_uplift_per_customer_inr

FROM promotion_comparison c

INNER JOIN promotions p
    ON c.promo_id = p.promo_id

;

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'customers'
ORDER BY ordinal_position;

SELECT *
FROM customers
LIMIT 5;