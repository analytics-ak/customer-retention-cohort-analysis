-- =================================================================================================
-- OLIST COHORT VALIDATION SUITE - PRODUCTION QUALITY CHECKS
-- Author: Ashish Dongre | Data Integrity Validation for Cohort Analysis
-- Purpose: Verify cohort retention calculations across 6 critical dimensions
-- Expected: ZERO rows from Sections 5-6 = Production Ready
-- =================================================================================================

-- -----------------------------------------------------------------------------
-- SECTION 1: Initialize Workspace
-- Purpose: Confirm database context and active schema
-- -----------------------------------------------------------------------------
SHOW DATABASES;
USE olist_data;

-- -----------------------------------------------------------------------------
-- SECTION 2: Base Table Integrity Check
-- Purpose: Audit aggregated order-level dataset after collapsing item-level rows
-- Expected: total_rows = unique_orders because each row represents one delivered order
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- SECTION 3: Customer Cohort Coverage
-- Purpose: Verify unique customers after filtering for successful deliveries only
-- Expected: Matches business expectation of active paying customer base
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- SECTION 4: Retention Month Range Validation
-- Purpose: Extract distinct month indexes (0,1,2...) to verify calculation continuity
-- Expected: Starts at 0 and allows visual inspection of month-number continuity up to maximum lifespan
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- SECTION 5: Cohort Lifespan Analysis
-- Purpose: Maximum retention duration per cohort month (longest surviving customers)
-- Expected: Earlier cohorts show longer max_month due to data availability
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- SECTION 6: Month 0 Integrity Check (CRITICAL VALIDATION)
-- Purpose: Confirm month_number=0 exactly equals cohort_size for ALL cohorts
-- Expected Result: ZERO rows returned = Perfect cohort definition
-- CRITICAL ALERT: Any rows returned indicates cohort calculation bug
-- -----------------------------------------------------------------------------
WITH base_orders AS (
    SELECT
        c.customer_unique_id,
        DATE(DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01')) AS order_month
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id,
        DATE(DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01'))
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
        c.cohort_month,
        b.order_month,
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
    s.cohort_month,
    s.cohort_size,
    r.customer_count AS month_0_customer_count
FROM cohort_sizes s
LEFT JOIN retention_counts r
    ON s.cohort_month = r.cohort_month
   AND r.month_number = 0
WHERE s.cohort_size <> r.customer_count;

-- -----------------------------------------------------------------------------
-- SECTION 7: Rate Boundary Validation (CRITICAL VALIDATION)
-- Purpose: Ensure retention rates stay between 0-100% mathematically
-- Expected Result: ZERO rows returned = No calculation errors
-- CRITICAL ALERT: Rows returned indicate division/rounding bugs
-- -----------------------------------------------------------------------------
WITH RECURSIVE base_orders AS (
    SELECT
        c.customer_unique_id,
        DATE(DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01')) AS order_month
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id,
        DATE(DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01'))
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
        c.cohort_month,
        b.order_month,
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
    ROUND(100.0 * r.customer_count / NULLIF(s.cohort_size, 0), 2) AS retention_rate_pct,
    ROUND(100.0 - (100.0 * r.customer_count / NULLIF(s.cohort_size, 0)), 2) AS churn_rate_pct
FROM retention_counts r
JOIN cohort_sizes s
    ON r.cohort_month = s.cohort_month
WHERE (100.0 * r.customer_count / NULLIF(s.cohort_size, 0)) > 100
   OR (100.0 - (100.0 * r.customer_count / NULLIF(s.cohort_size, 0))) < 0;