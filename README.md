<h1 align="center">Customer Retention Cohort Analysis</h1>
 
<p align="center">
  <b>SQL Project | Olist Brazilian E-Commerce Dataset</b><br>
  <sub>Pure SQL cohort retention analysis using MySQL, CTEs, recursive CTEs, retention rates, and churn analysis.</sub>
</p>
 
<p align="center">
  <img src="https://img.shields.io/badge/MySQL-8.0-blue?logo=mysql&logoColor=white" />
  <img src="https://img.shields.io/badge/Status-Completed-success" />
  <img src="https://img.shields.io/badge/Type-SQL%20Only-orange" />
</p>
 
---
 
## Problem Statement
 
In e-commerce, acquiring new customers is expensive. The real value comes when customers return and make repeat purchases.
 
This project analyzes customer behaviour using the **Olist dataset** to understand:
 
- How many customers return after their first purchase
- How long they stay active
- When most customers stop buying
 
Before analyzing retention, we also validate that only **delivered orders** are considered, to ensure accurate results.
 
---
 
## Key Questions
 
This project was built to answer these specific business questions:
 
1. Do customers come back after their first purchase?
2. How many months do customers stay active?
3. When does the biggest drop-off happen?
4. Do different cohorts behave differently over time?
 
---

## Key Insights

**98–99% of customers do not return after their first purchase.**

**Sharp Drop After First Purchase**  
Retention drops from 100% to below 0.5% immediately after Month 1. For example, the 2017-02 cohort falls from 1,628 customers to just 3 in Month 1 (0.18% retention).

**Extremely Low Retention Rates**  
For most cohorts, retention stays below 1–2% after the first month, showing that repeat purchase behaviour is almost negligible.

**Presence of Long-Term Customers**  
A small group of customers continues purchasing even after 10–20 months, forming a long-tail pattern. These customers represent the highest lifetime value segment.

**Consistent Behaviour Across Cohorts**  
Retention patterns remain nearly identical across cohorts, even when cohort sizes vary significantly. Increasing acquisition volume does not improve retention.

---
 
## Dataset
 
**Source:** Olist Brazilian E-Commerce Dataset (Kaggle)
🔗 [View Dataset on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
 
**Tables Used:**
 
| Table | Purpose |
|-------|---------|
| `customers` | Contains unique customer identifiers used to track repeat purchases |
| `orders` | Contains order timestamps and delivery status |
| `order_items` | Contains item price and freight (shipping cost) for each order |
 
**What the Data Represents:**
 
This dataset contains real e-commerce transactions over ~2 years (Sep 2016 – Oct 2018). It captures customer purchases, order timelines, and delivery outcomes — allowing us to track when a customer made their first purchase, how frequently they returned, and how long they remained active.
 
---
 
## Approach
 
**Step 1 — Data Filtering**
Only delivered orders were used to ensure valid customer transactions. Cancelled and unsuccessful orders were excluded.
 
**Step 2 — Cohort Creation**
For each customer, the first purchase date was identified. Customers were grouped into cohorts based on their **first purchase month**.
 
**Step 3 — Activity Tracking**
All customer purchases were mapped to monthly buckets. The time difference between the first purchase and subsequent purchases was calculated as `month_number` (Month 0, Month 1, etc.).
 
**Step 4 — Retention Calculation**
For each cohort and month, unique returning customers were counted and retention rate was calculated as a percentage of the original cohort.
 
---
 
## Key Metrics
 
| Metric | Description |
|--------|-------------|
| **Cohort Size** | Number of customers who made their first purchase in a given month |
| **Customer Count** | Number of customers from a cohort who returned in a specific month |
| **Retention Rate** | Percentage of customers retained from the original cohort (`customer_count ÷ cohort_size`) |
| **Churn Rate** | Percentage of customers who did not return (`100 − retention_rate`) |
 
---
 
## SQL Techniques Used
 
> **Tech Stack:** `MySQL 8.0` · `CTEs` · `Recursive CTEs` · `TIMESTAMPDIFF` · `CROSS JOIN` · `COALESCE`
 
- **Common Table Expressions (CTEs)** — Used to break the logic into modular steps, improving readability and maintainability
- **Time Difference Calculation** — Used `TIMESTAMPDIFF(MONTH, cohort_month, order_month)` to calculate the customer lifecycle in months
- **Dynamic Month Generation** — Used a recursive CTE to generate month numbers dynamically, ensuring the analysis adapts to future data
- **Aggregation & Deduplication** — Used `COUNT(DISTINCT customer_unique_id)` to accurately measure returning customers
 
---
 
## Final Output (Cohort Table)
 
<p align="center">
  <img src="cohort_retention_matrix.png" alt="Cohort Retention Table" width="700"/>
</p>
 
### How to Read the Table
 
- **Rows** represent `cohort_month` (first purchase month)
- **Columns** represent `month_number` (time since first purchase: Month 0 = first purchase, Month 1 = next month, and so on)
- **Values** show how many customers from that cohort returned in that month
 
**Example:** The `2017-01-01` cohort had **717 customers** at Month 0. By Month 1, only **2 customers** returned — a retention rate of just **0.28%**.
 
---
 
## Business Recommendations
 
| # | Recommendation | Details |
|---|---------------|---------|
| 1 | **Improve Month 1 Retention** | The largest drop occurs immediately after the first purchase. Introduce targeted follow-ups such as discount offers or reminder campaigns within 20–30 days of the first order. |
| 2 | **Build Loyalty Programs** | Identify long-term customers and offer incentives such as loyalty rewards or exclusive benefits to increase lifetime value. |
| 3 | **Analyze Delivery Experience** | Further analysis should be done on delivery timelines and customer experience to identify potential reasons for churn. |
| 4 | **Shift Focus to Retention** | High acquisition with low retention indicates inefficient marketing spend. Allocate more effort toward repeat purchase behaviour rather than only acquiring new customers. |
 
---
 
## Project Structure
 
```
/project-root
├── 01_data_setup.sql                         # Database creation, schema, data import, validation
├── 02_customer_retention_cohort_Analysis.sql # Main analysis: cohort, retention, churn
├── 03_validation.sql                         # Data integrity and consistency checks
└── README.md                                 # Project documentation
```
 
---
 
## Conclusion

This analysis shows that the business is mostly driven by one-time customers, with more than 98–99% of users not coming back after their first purchase.

The drop happens immediately after Month 0, and retention stays below 1–2% for most cohorts, which means repeat buying is almost non-existent.

> **The biggest takeaway is simple:** improving first-month retention will matter far more than bringing in more new customers.
 
---
 
## Author
 
**Ashish Kumar Dongre**
Data Analyst | Python, SQL, Pandas, Seaborn, Matplotlib
 
🔗 **LinkedIn:** [View My Profile](https://www.linkedin.com/in/analytics-ashish/)

📂 **Dataset:** [Olist Brazilian E-Commerce on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

💻 **GitHub:** [analytics-ak](https://github.com/analytics-ak)

📘 **SQL Files:** `Customer_Retention_Cohort_Analysis.sql` · `Data_setup.sql` · `validation.sql`
