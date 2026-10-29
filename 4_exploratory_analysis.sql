-- =============================================================================
-- 4_exploratory_analysis.sql
-- Exploratory operations, inventory, delivery, promotion, and customer analysis
-- =============================================================================
-- Dialect: PostgreSQL (FILTER, :: casts, date arithmetic, and NULLS LAST).
-- Prerequisites: populated orders_clean, stores_clean, inventory_clean, products,
-- deliveries, riders, promotions, promotion_exposures, and customers relations.
-- Unqualified relation names resolve using the session search_path; confirm it
-- points to the intended project schema. Metadata queries mostly inspect public.
--
-- Run in source order. All 44 statements, including intermediate inspections,
-- reporting views, and the partial index, are retained. CREATE OR REPLACE VIEW
-- updates persistent reporting definitions; CREATE INDEX persists an index.
-- No transaction wrapper, data filters, or SQL corrections have been added.
--
-- Scope: Business Questions 1 through 7.
-- Results are descriptive unless experimental assumptions are independently
-- validated. Comments describe the existing SQL rather than certify data quality.
-- =============================================================================

-- ============================================================================
-- Business Question 1: When and where do order volumes peak?
-- ============================================================================

-- Query 01
-- Inspect a small order sample before aggregation. LIMIT without ORDER BY returns an
-- unspecified sample.
SELECT * FROM orders_clean LIMIT 10;

-- Query 02
-- Compare recorded order volumes by store. LEFT JOIN retains unmatched stores; store IDs must
-- be unique in the dimension to avoid inflated counts.
SELECT
    o.store_id,
    s.store_name,
    COUNT(o.order_id) AS number_of_orders
FROM orders_clean o
LEFT JOIN stores_clean s ON o.store_id = s.store_id
GROUP BY o.store_id,s.store_name
ORDER BY number_of_orders DESC; 

-- Query 03
-- Describe demand by hour across all dated orders. No order-status or date-range filter is
-- applied; timestamp timezone determines the hour.
SELECT
    COUNT(order_id) AS number_of_orders,
    EXTRACT(HOUR FROM order_timestamp) as order_hour
FROM orders_clean
WHERE order_timestamp IS NOT NULL
GROUP BY EXTRACT(HOUR FROM order_timestamp)
ORDER BY order_hour;

-- Query 04
-- Find the five busiest store-hour combinations across the full dataset. INNER JOIN excludes
-- orders without a matching store; ties have no secondary sort.
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

-- Query 05
-- Compare total orders by weekday in Monday-to-Sunday order. Totals are not normalized for
-- unequal weekday coverage or store opening days.
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

-- ============================================================================
-- Business Question 2: Which products frequently go out of stock?
-- ============================================================================

-- Query 06
-- Inspect inventory records before measuring product availability. The sample has no guaranteed
-- order.
SELECT * FROM inventory_clean LIMIT 10;

-- Query 07
-- Rank products by observed inventory rows with any stockout time. A row is assumed to
-- represent one product-store-day; duplicate rows inflate frequency.
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

-- Query 08
-- Normalize stockout frequency by observed rows for each product. Missing days are not counted;
-- NULL stockout minutes remain in the denominator but not the numerator. Frequency does not
-- measure stockout duration or lost demand.
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

-- Query 09
-- Publish the same stockout measures for reporting across all products. The view has no
-- guaranteed row order and reflects current underlying data.
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

-- Query 10
-- Inspect the reusable product-stockout view. Apply an explicit ORDER BY in downstream reports
-- when ranking is needed.
SELECT * FROM vw_product_stockouts;

-- ============================================================================
-- Business Question 3: Which products are overstocked or wasted?
-- ============================================================================

-- Query 11
-- Rank products by recorded wastage cost in INR. Absolute cost reflects both scale and waste;
-- it is not a waste rate or proof of overstocking. SUM ignores NULL values.
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

-- Query 12
-- Expose total product wastage cost without a top-10 restriction for reporting. Product
-- dimension uniqueness is assumed.
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

-- Query 13
-- Inspect the public inventory table schema to identify fields available for stock-cover
-- analysis.
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'inventory_clean'
ORDER BY ordinal_position;

-- Query 14
-- Inspect five inventory rows as an intermediate data check; this is an unordered sample.
SELECT *
FROM inventory_clean
LIMIT 5;

-- Query 15
-- Estimate stock cover using the global latest inventory date and the inclusive 28-calendar-day
-- window ending on that date. AVG uses observed non-NULL rows, not a generated daily calendar.
-- Missing days and stockouts can bias the sales proxy. Store-product pairs absent on the latest
-- date or with nonpositive average sales are excluded. High cover is a screening signal; no
-- overstock threshold or shelf-life rule is applied.
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

-- ============================================================================
-- Business Question 4: What factors are associated with late deliveries?
-- ============================================================================

-- Query 16
-- Inspect delivery field names and types before examining delivery performance.
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'deliveries'
ORDER BY ordinal_position;

-- Query 17
-- Inspect an unordered delivery sample; retain this diagnostic query for reproducibility.
SELECT *
FROM deliveries
LIMIT 5;

-- Query 18
-- Establish delivery performance among rows with positive promised time and known actual time.
-- Lateness uses the recorded is_late flag; NULL flags remain in the denominator. AVG ignores
-- NULL values. These filters define the analysis population throughout this section.
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

-- Query 19
-- Compare average stage durations by recorded lateness flag. NULL flags form a separate group;
-- different stages may have different non-NULL sample sizes. Differences show associations and
-- do not establish causes.
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

-- Query 20
-- Compare distance, traffic, rainfall, and promise time by lateness group. Unadjusted averages
-- can reflect confounding by store, route, time, or demand.
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

-- Query 21
-- Compare lateness rates for traffic below 50, from 50 to below 70, and at least 70. These
-- cutoffs are analytical assumptions, not validated causal thresholds. Exclude missing traffic;
-- group sizes should inform interpretation.
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

-- Query 22
-- Publish traffic-group counts and lateness rates using the same eligibility rules and
-- thresholds as the exploratory query.
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

-- Query 23
-- Verify the traffic view in a meaningful Low-to-High display order.
SELECT *
FROM vw_delivery_traffic_lateness
ORDER BY
    CASE traffic_level
        WHEN 'Low' THEN 1
        WHEN 'Moderate' THEN 2
        WHEN 'High' THEN 3
    END;

-- ============================================================================
-- Business Question 5: How many delivery partners are required by store and hour?
-- ============================================================================

-- Query 24
-- Inspect rider metadata. This lookup filters only table name, so matching tables in multiple
-- accessible schemas may appear.
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'riders'
ORDER BY ordinal_position;

-- Query 25
-- Inspect rider records for context. The staffing estimates below do not use individual rider
-- availability or productivity.
SELECT *
FROM riders
LIMIT 5;

-- Query 26
-- Estimate average daily demand per store and order hour by dividing joined delivery counts by
-- 365. SQL has no year filter: a complete single 365-day period must be verified externally.
-- Order hour is a proxy for delivery workload hour; unique order keys are assumed.
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

-- Query 27
-- Translate average daily store-hour demand into whole riders using CEIL. Assume 2 deliveries
-- per rider-hour at 80% planned utilization, giving effective capacity of 1.6 deliveries per
-- rider-hour. Fixed annual averaging smooths peaks and does not model shifts, breaks,
-- variability, batching, or service-level targets. Missing store-hour combinations do not
-- appear as zero-demand rows.
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

-- Query 28
-- Publish the same staffing scenario for reporting. Capacity and the 365-day divisor are fixed
-- assumptions embedded in the view, not estimates from rider records.
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

-- Query 29
-- Check the number of store-hour groups in the staffing view; a row count alone does not
-- validate coverage or staffing adequacy.
SELECT COUNT(*)
FROM vw_hourly_rider_requirements;

-- ============================================================================
-- Business Question 6: Which discounts generate incremental demand?
-- ============================================================================

-- Query 30
-- Inspect promotion and exposure schemas before defining campaign eligibility and outcomes.
SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('promotions', 'promotion_exposures')
ORDER BY table_name, ordinal_position;

-- Query 31
-- Inspect an unordered promotion sample to understand campaign fields.
SELECT *
FROM promotions
LIMIT 5;

-- Query 32
-- Inspect an unordered assignment sample to understand exposure records.
SELECT *
FROM promotion_exposures
LIMIT 5;

-- Query 33
-- Check distinct assigned customers within each campaign and group. This does not establish
-- randomized assignment, group exclusivity, or baseline balance; validate those separately.
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

-- Query 34
-- Create a partial index supporting completed-order lookups by customer and timestamp. This is
-- a persistent database change retained from the source; execution requires suitable
-- privileges. IF NOT EXISTS checks the index name, not equivalence of its definition.
CREATE INDEX IF NOT EXISTS idx_orders_customer_completed_date
ON orders_clean (customer_id, order_timestamp)
WHERE order_status = 'Completed';

-- Query 35
-- Measure whether each assigned customer has any completed order from assigned_date through the
-- campaign end date (exclusive next-day boundary). All qualifying purchases count, regardless
-- of promo-code use. Start date is assigned_date; no separate campaign-start condition is
-- enforced.
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

-- Query 36
-- Compare treatment and control conversion in percentage points, not relative percent lift.
-- Exact group labels Control and Treatment are required; absent groups or zero denominators
-- yield NULL. PostgreSQL DESC defaults to NULLS FIRST, so missing comparisons may appear before
-- measured uplift. Causal interpretation requires valid randomization and no contamination;
-- uncertainty is not estimated.
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

-- Query 37
-- Inspect order field types before calculating gross-profit outcomes.
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'orders_clean'
ORDER BY ordinal_position;

-- Query 38
-- Sum completed-order gross profit in each assignment window and include non-purchasers with
-- zero profit. Repeated exposure rows can repeat profit while the denominator counts distinct
-- customers; assume one assignment per customer per promotion and mutually exclusive groups.
-- COALESCE also maps an all-NULL profit sum to zero.
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

-- Query 39
-- Compare conversion and gross profit per assigned customer across groups. LEFT JOIN preserves
-- non-purchasers; distinct customer counts do not prevent duplicated order-profit sums from
-- repeated exposure rows. Overlapping campaigns may count the same order in multiple campaigns.
-- Gross profit is not necessarily net incremental profit after all campaign costs; no
-- confidence intervals or significance tests are provided.
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

-- Query 40
-- Publish the same promotion comparisons for reporting, retaining their eligibility rules and
-- limitations. This view has no guaranteed row order and no stored snapshot.
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

-- ============================================================================
-- Business Question 7: Which customers are likely to stop ordering?
-- ============================================================================

-- Query 41
-- Inspect customer fields before preparing customer-level purchase history.
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'customers'
ORDER BY ordinal_position;

-- Query 42
-- Inspect an unordered customer sample; customer attributes are not used as churn labels here.
SELECT *
FROM customers
LIMIT 5;


-- ============================================================
-- BUSINESS QUESTION 7 OF 8
-- Which customers are likely to stop ordering?
-- ============================================================
--
-- Objective:
-- Analyse historical customer purchasing behaviour, build a
-- training dataset for churn prediction, and prepare customer
-- features for risk scoring using Python.
--
-- Approach:
-- 1. Examine customer purchase history and inactivity.
-- 2. Create historical Recency, Frequency, Monetary (RFM)
--    features and an observed non-return label.
-- 3. Prepare year-end customer features for risk scoring.
--
-- Predictive modelling and evaluation are performed in Python.
-- ============================================================


-- ------------------------------------------------------------
-- Query 43: Customer Purchase History and Inactivity
-- ------------------------------------------------------------
-- Calculate customer-level purchase frequency, total spending,
-- last purchase date, and recency as of 31 December 2025.
--
-- Includes all registered customers, even those without
-- completed purchases.
--
-- Customers without completed orders have:
--   total_completed_orders = 0
--   total_spend_inr = 0
--   last_order_date = NULL
--   days_since_last_order = NULL
--
-- These descriptive features are used to examine inactivity,
-- not directly as training features for historical predictions.
-- Using year-end information to predict earlier outcomes would
-- introduce data leakage.
--
-- Assumptions:
-- Customer IDs uniquely identify customers, and order IDs
-- uniquely identify orders. Customer signup dates are not used
-- to restrict the population as of the cutoff.

SELECT
    c.customer_id,

    MAX(o.order_timestamp)::DATE AS last_order_date,

    COUNT(o.order_id) AS total_completed_orders,

    ROUND(
        COALESCE(SUM(o.net_revenue_inr), 0),
        2
    ) AS total_spend_inr,

    DATE '2025-12-31'
        - MAX(o.order_timestamp)::DATE
        AS days_since_last_order

FROM customers c

LEFT JOIN orders_clean o
    ON c.customer_id = o.customer_id
    AND o.order_status = 'Completed'
    AND o.order_timestamp < DATE '2026-01-01'

GROUP BY
    c.customer_id

ORDER BY
    days_since_last_order DESC NULLS LAST;


-- ------------------------------------------------------------
-- Query 44: Customer Population Check
-- ------------------------------------------------------------
-- Count distinct customer IDs in the customer master table.
-- Provides a reference for checking the customer-level
-- purchasing history.
--
-- COUNT(DISTINCT) excludes NULL IDs and does not independently
-- identify duplicate customer records.

SELECT COUNT(DISTINCT customer_id)
FROM customers;


-- ============================================================
-- HISTORICAL CHURN TRAINING DATA
-- ============================================================
--
-- Feature period: Before 1 October 2025
-- Outcome period: 1 October to 31 December 2025
--
-- Target definition:
--   churn_label = 1 : No completed orders in the outcome period
--   churn_label = 0 : At least one completed order
--
-- The label represents non-purchase during a defined period,
-- not permanent customer churn.
--
-- Only customers who purchased before the historical cutoff
-- are included. Customers who never purchased are excluded.
--
-- The separation between feature and outcome periods prevents
-- future order information from entering the model inputs.
-- ============================================================


-- ------------------------------------------------------------
-- Query 45: Prepare Historical Churn Training Dataset
-- ------------------------------------------------------------
-- Generate three customer-level predictive features:
--
--   recency_days       : Days since last completed order
--                        as of 30 September 2025
--   frequency          : Completed orders before the cutoff
--   monetary_value_inr : Net revenue before the cutoff
--
-- Create churn_label from subsequent purchasing behaviour
-- during October–December 2025.
--
-- Output is exported to Python for logistic regression
-- training, validation, and evaluation.

WITH customer_history AS (
    SELECT
        c.customer_id,

        -- Last purchase before the historical cutoff
        MAX(o.order_timestamp) FILTER (
            WHERE o.order_timestamp < DATE '2025-10-01'
        )::DATE AS last_order_date,

        -- Purchase frequency before the cutoff
        COUNT(o.order_id) FILTER (
            WHERE o.order_timestamp < DATE '2025-10-01'
        ) AS total_completed_orders,

        -- Monetary value before the cutoff
        ROUND(
            COALESCE(
                SUM(o.net_revenue_inr) FILTER (
                    WHERE o.order_timestamp < DATE '2025-10-01'
                ),
                0
            ),
            2
        ) AS total_spend_inr,

        -- Purchases during the future observation period
        COUNT(o.order_id) FILTER (
            WHERE o.order_timestamp >= DATE '2025-10-01'
              AND o.order_timestamp < DATE '2026-01-01'
        ) AS future_completed_orders

    FROM customers c

    LEFT JOIN orders_clean o
        ON c.customer_id = o.customer_id
        AND o.order_status = 'Completed'
        AND o.order_timestamp < DATE '2026-01-01'

    GROUP BY c.customer_id
)

SELECT
    customer_id,

    -- Recency as of 30 September 2025
    DATE '2025-09-30' - last_order_date
        AS recency_days,

    total_completed_orders AS frequency,

    total_spend_inr AS monetary_value_inr,

    -- Target variable for Python classification
    CASE
        WHEN future_completed_orders = 0 THEN 1
        ELSE 0
    END AS churn_label

FROM customer_history

-- Exclude customers who had never purchased by the cutoff
WHERE total_completed_orders > 0

ORDER BY customer_id;


-- ============================================================
-- YEAR-END CUSTOMER RISK SCORING
-- ============================================================
--
-- Scoring date: 31 December 2025
-- Feature period: 1 April to 31 December 2025
--
-- The nine-month feature window matches the duration used
-- in the historical training dataset.
--
-- Only customers with at least one completed order within
-- the feature period are included.
--
-- The output contains the same three predictive features
-- as the training dataset, without a churn label.
--
-- The trained Python model estimates the probability that
-- a customer will not order during the next three months.
-- Future outcomes are not available for verification.
-- ============================================================


-- ------------------------------------------------------------
-- Query 46: Prepare Customer Churn-Risk Scoring Dataset
-- ------------------------------------------------------------
-- Calculate recency, frequency, and monetary value using
-- completed orders from April through December 2025.
--
-- Exclude customers with no completed orders during this
-- period; they require separate inactivity/reactivation
-- consideration rather than scoring with this model.
--
-- Export the resulting customer features to Python and
-- apply the previously trained logistic regression model.
--
-- The selected classification threshold is 0.20, based
-- on validation-set performance.

WITH customer_history AS (
    SELECT
        c.customer_id,

        MAX(o.order_timestamp)::DATE AS last_order_date,

        COUNT(o.order_id) AS total_completed_orders,

        ROUND(
            COALESCE(SUM(o.net_revenue_inr), 0),
            2
        ) AS total_spend_inr

    FROM customers c

    LEFT JOIN orders_clean o
        ON c.customer_id = o.customer_id
        AND o.order_status = 'Completed'
        AND o.order_timestamp >= DATE '2025-04-01'
        AND o.order_timestamp < DATE '2026-01-01'

    GROUP BY
        c.customer_id
)

SELECT
    customer_id,

    DATE '2025-12-31' - last_order_date AS recency_days,

    total_completed_orders AS frequency,

    total_spend_inr AS monetary_value_inr

FROM customer_history

WHERE total_completed_orders > 0

ORDER BY customer_id;


-- ============================================================
-- END OF BUSINESS QUESTION 7
-- ============================================================
--
-- Python analysis summary:
--
-- Historical training dataset: 8,035 customers
-- Churn model: Logistic Regression
-- Predictors: Recency, Frequency, Monetary Value
--
-- Held-out test performance:
--   ROC-AUC          : 0.7586
--   Churn recall     : 64.6%
--   Churn precision  : 32.8%
--   Churn F1-score   : 0.44
--   Selected threshold: 0.20
--
-- Year-end customer risk scoring:
--   Customers scored      : 8,285
--   Customers flagged     : 2,979
--   Retention targets     : 1,663
--   Reactivation targets  : 1,316
--
-- Retention targets have recency <= 90 days.
-- Reactivation targets have recency > 90 days.
-- This is an operational grouping, not a validated churn cutoff.
--
-- Model limitations:
--   - Single historical cutoff and customer-level holdout.
--   - Low precision produces substantial false positives.
--   - Predicted probabilities are not independently calibrated.
--   - Predictions for January–March 2026 are unverified.
--
-- Business implication:
-- Prioritize low-cost, targeted retention outreach and
-- separately evaluate reactivation interventions.
-- ============================================================
