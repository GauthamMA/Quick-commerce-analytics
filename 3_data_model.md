# Quick Commerce Analytics — Data Model

## 1. Overview

The project uses a PostgreSQL relational database containing 11 tables representing a fictional quick-commerce business operating across 10 dark stores in Bengaluru.

The analytical model follows a star-schema-style structure, with fact tables recording business activities and measurements, and dimension tables providing descriptive information.

The model supports analysis of order demand, delivery performance, inventory management, promotional effectiveness and customer retention.

## 2. Fact Tables

| Table | Grain (One Row Represents) | Primary Key |
|---|---|---|
| `orders_clean` | One customer order | `order_id` |
| `order_items_clean` | One product line within an order | `order_item_id` |
| `deliveries` | One delivery | `delivery_id` |
| `inventory_clean` | One product at one store on one date | `inventory_record_id` |
| `promotion_exposures` | One customer promotion assignment | `exposure_id` |

These tables contain transaction records, operational measurements and identifiers linking them to related tables.

## 3. Dimension Tables

| Table | Description | Primary Key |
|---|---|---|
| `customers` | Customer profiles and segments | `customer_id` |
| `products` | Product details, categories and prices | `product_id` |
| `stores_clean` | Dark-store locations and characteristics | `store_id` |
| `riders` | Delivery partner information | `rider_id` |
| `promotions` | Promotional campaign details | `promo_id` |

Dimension tables provide descriptive attributes used to group, filter and interpret business measurements.

## 4. Table Relationships

The following foreign key relationships are enforced in PostgreSQL:

### Orders

- `orders_clean.customer_id` → `customers.customer_id`
- `orders_clean.store_id` → `stores_clean.store_id`
- `orders_clean.promo_id` → `promotions.promo_id`

### Order Items

- `order_items_clean.order_id` → `orders_clean.order_id`
- `order_items_clean.product_id` → `products.product_id`

### Deliveries

- `deliveries.order_id` → `orders_clean.order_id`
- `deliveries.rider_id` → `riders.rider_id`

### Inventory

- `inventory_clean.store_id` → `stores_clean.store_id`
- `inventory_clean.product_id` → `products.product_id`

### Promotion Exposures

- `promotion_exposures.promo_id` → `promotions.promo_id`
- `promotion_exposures.customer_id` → `customers.customer_id`

## 5. External Factors

The `external_factors` table contains weather, rainfall, traffic and event information at the zone-and-date level.

Its composite primary key is (`date`, `zone`).

This table provides contextual information for investigating delivery delays and changes in demand. It is not connected through a database foreign key in the current model.

## 6. Data Preparation

Data-quality checks were performed before establishing the analytical model.

- Removed 29 exact duplicate order records.
- Removed 43 exact duplicate order-item records.
- Removed 29 exact duplicate inventory records.
- Standardized inconsistent store names.
- Identified 48 orders with missing order timestamps and 32 deliveries with missing completion timestamps.
- Verified essential numerical fields, table grains and referential integrity.
- Established primary key and foreign key constraints.

Original raw tables were retained where separate cleaned tables were created.

The resulting database provides a consistent foundation for exploratory analysis, decision modelling and business reporting.