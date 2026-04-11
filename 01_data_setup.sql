#----------------------------------------------------------------------------------------------------------------------
#-- DATABASE SETUP: Initialize workspace and enable local data loading permissions
#----------------------------------------------------------------------------------------------------------------------
SHOW DATABASES;
CREATE DATABASE olist_data;
USE olist_data;

SET GLOBAL local_infile = 1;
SET SESSION local_infile = 1;

#----------------------------------------------------------------------------------------------------------------------
#-- CUSTOMERS TABLE: Define schema and import primary customer demographics
#----------------------------------------------------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id VARCHAR(50) NOT NULL PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INT,
    customer_zip_code_suffix VARCHAR(4),
    customer_city VARCHAR(50),
    customer_state VARCHAR(2)
);

LOAD DATA LOCAL INFILE '.../customers_dataset.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, customer_unique_id, customer_zip_code_prefix, customer_zip_code_suffix, customer_city, customer_state);


#----------------------------------------------------------------------------------------------------------------------
#-- ORDERS TABLE: Define schema and import main order transaction data
#----------------------------------------------------------------------------------------------------------------------
CREATE TABLE orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    order_status VARCHAR(15),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME
);

LOAD DATA LOCAL INFILE '.../orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date);


#----------------------------------------------------------------------------------------------------------------------
#-- ORDER ITEMS TABLE: Define schema and import granular line-item data including pricing/freight
#----------------------------------------------------------------------------------------------------------------------
CREATE TABLE order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(10, 4),
    freight_value DECIMAL(10, 4)
);

LOAD DATA LOCAL INFILE '.../order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value);


#----------------------------------------------------------------------------------------------------------------------
#-- DATA AUDIT: Verify total record counts across all imported tables
#----------------------------------------------------------------------------------------------------------------------
SELECT COUNT(*) AS total_customers FROM customers;
SELECT COUNT(*) AS total_orders FROM orders;
SELECT COUNT(*) AS total_order_items FROM order_items;


#----------------------------------------------------------------------------------------------------------------------
#-- QUALITY CHECK: Identify any missing values in the unique customer identifier
#----------------------------------------------------------------------------------------------------------------------
SELECT COUNT(*) AS null_unique_customers
FROM customers
WHERE customer_unique_id IS NULL;


#----------------------------------------------------------------------------------------------------------------------
#-- DUPLICATE ANALYSIS: Check for redundant entries in Customers and Orders tables
#----------------------------------------------------------------------------------------------------------------------
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT customer_id) AS unique_customers,
       COUNT(*) - COUNT(DISTINCT customer_id) AS duplicates
FROM customers;

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT order_id) AS unique_orders,
       COUNT(*) - COUNT(DISTINCT order_id) AS duplicates
FROM orders;

#-- Check for duplicate line items using a composite of order and item IDs
SELECT COUNT(*) - COUNT(DISTINCT CONCAT(order_id, '_', order_item_id)) AS true_duplicates
FROM order_items;


#----------------------------------------------------------------------------------------------------------------------
#-- TIME RANGE: Establish the chronological boundaries of the dataset
#----------------------------------------------------------------------------------------------------------------------
SELECT MIN(order_purchase_timestamp) AS min_date,
       MAX(order_purchase_timestamp) AS max_date
FROM orders;


#----------------------------------------------------------------------------------------------------------------------
#-- STATUS DISTRIBUTION: Breakdown of orders by their current lifecycle stage
#----------------------------------------------------------------------------------------------------------------------
SELECT order_status, COUNT(*) AS total_orders
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;


#----------------------------------------------------------------------------------------------------------------------
#-- REFERENTIAL INTEGRITY: Ensure all order records map correctly to existing customers and items
#----------------------------------------------------------------------------------------------------------------------
SELECT COUNT(*) AS missing_customers
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

SELECT COUNT(*) AS missing_orders
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

#----------------------------------------------------------------------------------------------------------------------
#-- PERFORMANCE OPTIMIZATION: Create indexes on foreign keys to speed up future join operations
#----------------------------------------------------------------------------------------------------------------------
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_items_order ON order_items(order_id);
CREATE INDEX idx_orders_status_date ON orders(order_status, order_purchase_timestamp);
#----------------------------------------------------------------------------------------------------------------------