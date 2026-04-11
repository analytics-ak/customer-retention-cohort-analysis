#----------------------------------------------------------------------------------------------------------------------
#-- Initialize workspace
#----------------------------------------------------------------------------------------------------------------------
SHOW DATABASES;
USE olist_data;

#----------------------------------------------------------------------------------------------------------------------
#----------------------------------------  COHORT RETENTION ANALYSIS --------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------------------------------
#-- DELIVERY PERFORMANCE: Calculate delivery success rate by comparing 'delivered' counts against the full order volume
#-----------------------------------------------------------------------------------------------------------------------
WITH order_summary AS (
	SELECT 
		COUNT(*) AS total_orders,
		SUM(CASE WHEN orders.order_status = 'delivered' THEN 1 END) AS delivered_orders
	FROM orders
)

SELECT 
	total_orders, 
    delivered_orders,
    ROUND((delivered_orders/total_orders)*100, 2) AS delivery_rate_pct
FROM order_summary;

#-------------------------------------------------------------------------------------------------------------------------


#----------------------------------------------------------------------------------------------------------------------
#-- BASE REVENUE TABLE: Aggregate total order value (Price + Freight) for delivered orders per customer
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
    customer_unique_id,
    order_id,
    purchase_date,
    total_price + total_freight AS total_order_value
FROM base_orders;
#----------------------------------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------------------------------
#-- COHORT IDENTIFICATION: Determine the initial acquisition date for each unique customer
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
    customer_unique_id,
    MIN(purchase_date) AS first_purchase_date
FROM base_orders
GROUP BY customer_unique_id;
#----------------------------------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------------------------------
#-- COHORT SEGMENTATION: Map each customer to their first purchase month to establish primary cohort groups
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
    customer_unique_id,
    first_purchase_date,
    DATE(DATE_FORMAT(first_purchase_date, '%Y-%m-01')) AS cohort_month
FROM first_purchase;
#----------------------------------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------------------------------
#-- REVENUE MAPPING: Aggregate total revenue per order and normalize purchase dates into monthly buckets
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
),
order_months AS (
    SELECT
        customer_unique_id,
        order_id,
        purchase_date,
        DATE(DATE_FORMAT(purchase_date, '%Y-%m-01')) AS order_month,
        total_price + total_freight AS total_order_value
    FROM base_orders
)
SELECT *
FROM order_months;
#----------------------------------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------------------------------
#-- COHORT RETENTION: Calculate the month-over-month lifespan of each customer relative to their first purchase
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
)
SELECT
    b.customer_unique_id,
    b.order_month,
    c.cohort_month,
    TIMESTAMPDIFF(MONTH, c.cohort_month, b.order_month) AS month_number
FROM base_orders b
JOIN cohorts c
    ON b.customer_unique_id = c.customer_unique_id;
#----------------------------------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------------------------------
#-- RETENTION ANALYSIS: Aggregate unique customer counts per cohort and tracked month index
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
SELECT
    cohort_month,
    month_number,
    COUNT(DISTINCT customer_unique_id) AS customer_count
FROM cohort_activity
GROUP BY
    cohort_month,
    month_number
ORDER BY
    cohort_month,
    month_number;
#----------------------------------------------------------------------------------------------------------------------
    
#----------------------------------------------------------------------------------------------------------------------
#-- FINAL RETENTION MATRIX: Full cohort report including months with zero customer activity
#----------------------------------------------------------------------------------------------------------------------
WITH RECURSIVE
base_orders AS (
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
),
retention_counts AS (
    SELECT
        cohort_month,
        month_number,
        COUNT(DISTINCT customer_unique_id) AS customer_count
    FROM cohort_activity
    GROUP BY
        cohort_month,
        month_number
),
cohort_list AS (
    SELECT DISTINCT cohort_month
    FROM cohorts
),
max_month AS (
    SELECT MAX(month_number) AS max_month_number
    FROM cohort_activity
),
months AS (
    SELECT 0 AS month_number
    UNION ALL
    SELECT month_number + 1
    FROM months
    WHERE month_number < (SELECT max_month_number FROM max_month)
)
SELECT
    cl.cohort_month,
    m.month_number,
    COALESCE(r.customer_count, 0) AS customer_count
FROM cohort_list cl
CROSS JOIN months m
LEFT JOIN retention_counts r
    ON cl.cohort_month = r.cohort_month
   AND m.month_number = r.month_number
ORDER BY
    cl.cohort_month,
    m.month_number;
#----------------------------------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------------------------------
#-- COHORT SIZE ANALYSIS: Isolate the baseline acquisition count (Month 0) for each customer cohort
#----------------------------------------------------------------------------------------------------------------------
WITH cohorts AS (
    SELECT
        c.customer_unique_id,
        DATE(DATE_FORMAT(MIN(o.order_purchase_timestamp), '%Y-%m-01')) AS cohort_month
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    cohort_month,
    COUNT(*) AS cohort_size
FROM cohorts
GROUP BY cohort_month
ORDER BY cohort_month;
#----------------------------------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------------------------------
#-- RETENTION PERFORMANCE: Join active counts with baseline cohort sizes to calculate percentage retention rates
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
),
retention_counts AS (
    SELECT
        cohort_month,
        month_number,
        COUNT(DISTINCT customer_unique_id) AS customer_count
    FROM cohort_activity
    GROUP BY
        cohort_month,
        month_number
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(*) AS cohort_size
    FROM cohorts
    GROUP BY cohort_month
)
SELECT
    r.cohort_month,
    r.month_number,
    r.customer_count,
    s.cohort_size,
    ROUND(100.0 * r.customer_count / s.cohort_size, 2) AS retention_rate,
    ROUND(100.0 - (100.0 * r.customer_count / s.cohort_size), 2) AS churn_rate
FROM retention_counts r
JOIN cohort_sizes s
    ON r.cohort_month = s.cohort_month
ORDER BY
    r.cohort_month,
    r.month_number;
#----------------------------------------------------------------------------------------------------------------------