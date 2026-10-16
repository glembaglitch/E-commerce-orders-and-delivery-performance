# E-commerce Orders and Delivery Performance

## Overview

This PostgreSQL project explores the Olist e-commerce dataset using customer, order, and order-item data. The SQL script creates the core tables and includes queries for revenue, monthly sales trends, repeat purchases, delivery timing, customer segmentation, and customer-state performance.

## Files

- `ecommercescript.sql` — creates the schema and tables, then runs data checks and analysis queries.

## Data required

The script is designed for these CSV files:

- `olist_customers_dataset.csv`
- `olist_orders_dataset.csv`
- `olist_order_items_dataset.csv`

The script creates the tables but does not load the CSV files. Import each CSV into its matching table using DBeaver's **Import Data** wizard. Enable the header row and check that the CSV columns map to the table columns.

Import the orders before order items. The `order_items` table has a foreign key to `orders`, so each item row must refer to an order that already exists.

## Important schema setup

The script currently contains two different schema names:

```sql
CREATE SCHEMA olistecommerce;
SET search_path TO olistecommercedata;
```

Choose one schema name and use it in both statements before running the script. For example, to use `olistecommercedata`:

```sql
CREATE SCHEMA olistecommercedata;
SET search_path TO olistecommercedata;
```

The table creation statements do not use `IF NOT EXISTS`, so run them once in a new schema or database. Rerunning them after the tables already exist will produce errors.

## Tables

- `customers` — customer identifiers, ZIP-code prefix, city, and state.
- `orders` — order status and purchase, approval, delivery, and estimated-delivery timestamps.
- `order_items` — products and sellers in each order, item prices, freight, and shipping-limit timestamps. Its composite primary key is `(order_id, order_item_id)`.

## Analyses included

- Counts null values in the `orders` table.
- Calculates order count, product revenue, freight, and gross revenue from order items.
- Summarizes delivered-order sales by purchase month and calculates month-over-month revenue change and growth.
- Calculates the share of customers with more than one delivered order.
- Lists delivery durations and compares actual delivery dates with estimates.
- Calculates time between a customer's successive orders.
- Segments delivered-order customers using Recency, Frequency, and Monetary (RFM) scores.
- Compares order volume and item revenue across customer states.

## Metric notes

- Product revenue is the sum of `order_items.price`.
- Freight is the sum of `order_items.freight_value`.
- Gross revenue in the script is product revenue plus freight.
- The all-time total query includes every order item. The monthly sales and growth queries filter to orders with `order_status = 'delivered'` and group them by purchase month.
- Missing order timestamps can be legitimate—for example, an order may not have been approved or delivered. The script checks for nulls but does not replace missing dates with guessed values.
- The delivery comparison returns one row per delivered order. `late_deliveries` is set to `1` when actual delivery is after the estimated date; `days_from_estimate` is positive for early delivery and negative for late delivery.

## Running the project in DBeaver

1. Connect to the PostgreSQL database and open a SQL Editor.
2. Make the schema names consistent as described above.
3. Run the schema and table-creation statements.
4. Import the three CSV files into their corresponding tables, with the CSV header enabled.
5. Run the data-check and analysis queries in the script.

The SQL uses PostgreSQL features such as `FILTER`, `DATE_TRUNC`, `GENERATE_SERIES`, window functions, and `NTILE`.
