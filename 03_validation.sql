#----------------------------------------------------------------------------------------------------------------------
#-- Initialize workspace
#----------------------------------------------------------------------------------------------------------------------
SHOW DATABASES;
USE olist_data;

#----------------------------------------------------------------------------------------------------------------------
#-- DATA VALIDATION: Audit the aggregated dataset to ensure row counts match unique order IDs
#----------------------------------------------------------------------------------------------------------------------
WITH base_orders AS (
    SELECT 
        c.customer_unique_id, 
        o.order_id, 
        o.order_purchase_timestamp AS purchase_date,
        SUM(oi.price) AS total_price,
        SUM(oi.freight_value) AS total_freight
    FROM customers c
    JOIN orders o 
        ON c.customer_id = o.customer_id
    JOIN order_items oi 
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY 
        c.customer_unique_id, 
        o.order_id, 
        o.order_purchase_timestamp
)
SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders
FROM base_orders;
#----------------------------------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------------------------------
#-- COHORT VALIDATION: Verify the final count of unique customers after filtering for successful deliveries
#----------------------------------------------------------------------------------------------------------------------
WITH base_orders AS (
    SELECT 
        c.customer_unique_id,
        o.order_purchase_timestamp AS purchase_date
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
first_purchase AS (
    SELECT
        customer_unique_id,
        MIN(purchase_date) AS first_purchase_date
    FROM base_orders
    GROUP BY customer_unique_id
)
SELECT 
    COUNT(*) AS total_customers
FROM first_purchase;
#----------------------------------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------------------------------
#-- RETENTION RANGE: Extract a distinct list of month indexes to verify the maximum lifespan of customers
#----------------------------------------------------------------------------------------------------------------------
WITH base_orders AS (
    SELECT 
        c.customer_unique_id,
        o.order_id,
        DATE(DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01')) AS order_month
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
),
cohorts AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM base_orders
    GROUP BY customer_unique_id
),
cohort_activity AS (
    SELECT
        b.customer_unique_id,
        b.order_month,
        c.cohort_month,
        TIMESTAMPDIFF(MONTH, c.cohort_month, b.order_month) AS month_number
    FROM base_orders b
    JOIN cohorts c
        ON b.customer_unique_id = c.customer_unique_id
)
SELECT DISTINCT
    month_number
FROM cohort_activity
ORDER BY month_number;
#----------------------------------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------------------------------
#-- COHORT LIFESPAN: Identify the maximum retention duration (in months) for each specific customer cohort
#----------------------------------------------------------------------------------------------------------------------
 WITH base_orders AS (
    SELECT 
        c.customer_unique_id,
        o.order_id,
        DATE(DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01')) AS order_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, o.order_id, o.order_purchase_timestamp
),
cohorts AS (
    SELECT customer_unique_id,
           MIN(order_month) AS cohort_month
    FROM base_orders
    GROUP BY customer_unique_id
)
SELECT
    c.cohort_month,
    MAX(TIMESTAMPDIFF(MONTH, c.cohort_month, b.order_month)) AS max_month
FROM base_orders b
JOIN cohorts c ON b.customer_unique_id = c.customer_unique_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;
#----------------------------------------------------------------------------------------------------------------------