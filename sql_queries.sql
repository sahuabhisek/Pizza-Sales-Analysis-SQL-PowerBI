 -- =====================================================================
-- SCHEMA (works in SQLite / PostgreSQL / MySQL; adjust types if needed)
                                               -- =====================================================================
CREATE TABLE customers (
  customer_id         INT PRIMARY KEY,
  customer_name       VARCHAR(100),
  email               VARCHAR(100),
  gender              VARCHAR(10),
  age                 INT,
  city                VARCHAR(50),                                                                            
  state               VARCHAR(50),
  signup_date         DATE,
  acquisition_channel VARCHAR(30)
);
CREATE TABLE products (
  product_id   INT PRIMARY KEY,
  product_name VARCHAR(100),
  category     VARCHAR(50),
  brand        VARCHAR(50),
  price        DECIMAL(10,2),
  cost_price   DECIMAL(10,2),
  stock_qty    INT
);
CREATE TABLE orders (
  order_id       INT PRIMARY KEY,
  customer_id    INT REFERENCES customers(customer_id),
  product_id     INT REFERENCES products(product_id),
  order_date     DATE,
  quantity       INT,
  discount_pct   INT,
  total_amount   DECIMAL(12,2),
  payment_method VARCHAR(30),
  order_status   VARCHAR(20)
);
CREATE TABLE healthcare (
  visit_id             INT PRIMARY KEY,
  patient_id           INT,
  gender               VARCHAR(10),
  age                  INT,
  city                 VARCHAR(50),
  admission_date       DATE,
  discharge_date       DATE,
  department           VARCHAR(50),
  doctor_name          VARCHAR(50),
  diagnosis            VARCHAR(50),
  admission_type       VARCHAR(30),
  length_of_stay_days  INT,
  total_bill           DECIMAL(12,2),
  insurance_provider   VARCHAR(30),
  insurance_covered    DECIMAL(12,2),
  outcome              VARCHAR(20),
  readmitted_30d       INT
);

-- Load the CSVs (see PDF page 2), then run the queries below. Written for SQLite; see dialect cheat sheet.


-- ====================================================================
-- PROJECT 1: E-COMMERCE
-- ====================================================================

-- E1. What are our total revenue, orders and average order value?
-- Why: Headline KPIs every dashboard starts with. Only delivered orders count as real revenue.
SELECT COUNT(*)                         AS total_orders,
       COUNT(DISTINCT customer_id)      AS buyers,
       ROUND(SUM(total_amount), 0)      AS revenue,
       ROUND(AVG(total_amount), 0)      AS avg_order_value
FROM orders
WHERE order_status = 'Delivered';

-- E2. How is monthly revenue trending, and what is the month-over-month growth?
-- Why: Shows seasonality and whether the business is growing or slowing.
WITH m AS (
  SELECT strftime('%Y-%m', order_date) AS month,
         SUM(total_amount)             AS revenue
  FROM orders
  WHERE order_status = 'Delivered'
  GROUP BY 1
)
SELECT month,
       ROUND(revenue, 0) AS revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / LAG(revenue) OVER (ORDER BY month), 1) AS mom_growth_pct
FROM m
ORDER BY month;

-- E3. Who are our top 10 customers by lifetime spend?
-- Why: Identifies VIP customers for loyalty programs and personal outreach.
SELECT c.customer_id, c.customer_name, c.city,
       COUNT(o.order_id)           AS orders,
       ROUND(SUM(o.total_amount),0) AS lifetime_spend
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'Delivered'
GROUP BY c.customer_id, c.customer_name, c.city
ORDER BY lifetime_spend DESC
LIMIT 10;

-- E4. Which product categories bring the most revenue and profit?
-- Why: Revenue alone can mislead. Margin shows which categories really make money.
SELECT p.category,
       SUM(o.quantity)                                        AS units_sold,
       ROUND(SUM(o.total_amount), 0)                          AS revenue,
       ROUND(SUM(o.total_amount - p.cost_price * o.quantity), 0) AS profit,
       ROUND(100.0 * SUM(o.total_amount - p.cost_price * o.quantity)
             / SUM(o.total_amount), 1)                        AS margin_pct
FROM orders o
JOIN products p ON o.product_id = p.product_id
WHERE o.order_status = 'Delivered'
GROUP BY p.category
ORDER BY revenue DESC;

-- E5. What are the top 3 products by revenue inside each category?
-- Why: Helps merchandising decide which products to feature and stock deeper.
WITH r AS (
  SELECT p.category, p.product_name,
         SUM(o.total_amount) AS revenue,
         ROW_NUMBER() OVER (PARTITION BY p.category
                            ORDER BY SUM(o.total_amount) DESC) AS rn
  FROM orders o
  JOIN products p ON o.product_id = p.product_id
  WHERE o.order_status = 'Delivered'
  GROUP BY p.category, p.product_id, p.product_name
)
SELECT category, product_name, ROUND(revenue,0) AS revenue, rn AS rank_in_category
FROM r
WHERE rn <= 3
ORDER BY category, rn;

-- E6. Which registered customers have never placed an order?
-- Why: These are warm leads. A first-order coupon campaign can convert them.
SELECT c.customer_id, c.customer_name, c.acquisition_channel, c.signup_date
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL
ORDER BY c.signup_date;

-- E7. Which payment methods have the highest cancellation and return rates?
-- Why: High failure rates on a payment method point to checkout or fraud problems (for example Cash on Delivery).
SELECT payment_method,
       COUNT(*) AS orders,
       ROUND(100.0 * SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 1) AS cancel_pct,
       ROUND(100.0 * SUM(CASE WHEN order_status = 'Returned'  THEN 1 ELSE 0 END) / COUNT(*), 1) AS return_pct
FROM orders
GROUP BY payment_method
ORDER BY cancel_pct DESC;

-- E8. Which states and cities generate the most revenue, and what share of the total is that?
-- Why: Guides regional marketing spend and warehouse placement.
SELECT c.state, c.city,
       ROUND(SUM(o.total_amount), 0) AS revenue,
       ROUND(100.0 * SUM(o.total_amount)
             / SUM(SUM(o.total_amount)) OVER (), 1) AS pct_of_total
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'Delivered'
GROUP BY c.state, c.city
ORDER BY revenue DESC;

-- E9. Which acquisition channel brings the most valuable customers?
-- Why: Marketing should spend on channels with the highest revenue per customer, not just the most signups.
SELECT c.acquisition_channel,
       COUNT(DISTINCT c.customer_id)                  AS customers,
       COUNT(o.order_id)                              AS orders,
       ROUND(COALESCE(SUM(o.total_amount), 0), 0)     AS revenue,
       ROUND(COALESCE(SUM(o.total_amount), 0)
             / COUNT(DISTINCT c.customer_id), 0)      AS revenue_per_customer
FROM customers c
LEFT JOIN orders o
       ON c.customer_id = o.customer_id AND o.order_status = 'Delivered'
GROUP BY c.acquisition_channel
ORDER BY revenue_per_customer DESC;

-- E10. What share of customers are repeat buyers, and how much revenue do they bring?
-- Why: Retention is cheaper than acquisition. This shows how much the business depends on repeat customers.
WITH t AS (
  SELECT customer_id, COUNT(*) AS n, SUM(total_amount) AS spend
  FROM orders
  WHERE order_status = 'Delivered'
  GROUP BY customer_id
)
SELECT CASE WHEN n = 1 THEN 'One-time' ELSE 'Repeat' END AS customer_type,
       COUNT(*)                                         AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_customers,
       ROUND(SUM(spend), 0)                             AS revenue,
       ROUND(100.0 * SUM(spend) / SUM(SUM(spend)) OVER (), 1) AS pct_revenue
FROM t
GROUP BY 1;

-- E11. Segment customers with RFM (Recency, Frequency, Monetary) scoring.
-- Why: The classic analyst deliverable: lets marketing target Champions, At-Risk and Lapsed customers differently.
WITH base AS (
  SELECT customer_id, MAX(order_date) AS last_order,
         COUNT(*) AS frequency, SUM(total_amount) AS monetary
  FROM orders WHERE order_status = 'Delivered'
  GROUP BY customer_id
),
scored AS (
  SELECT customer_id, frequency, monetary,
         NTILE(4) OVER (ORDER BY last_order) AS r,
         NTILE(4) OVER (ORDER BY frequency)  AS f,
         NTILE(4) OVER (ORDER BY monetary)   AS m
  FROM base
),
seg AS (
  SELECT *, CASE WHEN r = 4 AND f >= 3 AND m >= 3 THEN 'Champion'
                 WHEN r >= 3                      THEN 'Active'
                 WHEN r <= 2 AND m >= 3           THEN 'At Risk (high value)'
                 ELSE 'Low value / lapsed' END AS segment
  FROM scored
)
SELECT segment, COUNT(*) AS customers,
       ROUND(AVG(monetary), 0) AS avg_spend,
       ROUND(AVG(frequency), 1) AS avg_orders
FROM seg
GROUP BY segment
ORDER BY avg_spend DESC;

-- E12. Do bigger discounts increase basket size, or just increase returns?
-- Why: Checks whether discounting actually pays off.
SELECT CASE WHEN discount_pct = 0  THEN '1. No discount'
             WHEN discount_pct <= 10 THEN '2. 5-10%'
             ELSE '3. 15-20%' END AS discount_band,
       COUNT(*)                         AS orders,
       ROUND(AVG(quantity), 2)          AS avg_qty,
       ROUND(AVG(total_amount), 0)      AS avg_order_value,
       ROUND(100.0 * SUM(CASE WHEN order_status = 'Returned' THEN 1 ELSE 0 END) / COUNT(*), 1) AS return_pct
FROM orders
GROUP BY 1
ORDER BY 1;

-- E13. How does revenue differ by age group and gender?
-- Why: Helps target ads and pick the right creative for each demographic.
SELECT CASE WHEN c.age < 25 THEN '18-24' WHEN c.age < 35 THEN '25-34'
             WHEN c.age < 45 THEN '35-44' WHEN c.age < 55 THEN '45-54'
             ELSE '55+' END AS age_group,
       c.gender,
       COUNT(DISTINCT c.customer_id)  AS customers,
       ROUND(SUM(o.total_amount), 0)  AS revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'Delivered'
GROUP BY 1, 2
ORDER BY 1, 2;

-- E14. Which day of the week is the busiest?
-- Why: Used to schedule flash sales, email campaigns and customer-support staffing.
SELECT CASE strftime('%w', order_date)
         WHEN '0' THEN 'Sun' WHEN '1' THEN 'Mon' WHEN '2' THEN 'Tue'
         WHEN '3' THEN 'Wed' WHEN '4' THEN 'Thu' WHEN '5' THEN 'Fri'
         ELSE 'Sat' END                  AS weekday,
       COUNT(*)                          AS orders,
       ROUND(SUM(total_amount), 0)       AS revenue
FROM orders
WHERE order_status = 'Delivered'
GROUP BY strftime('%w', order_date)
ORDER BY strftime('%w', order_date);

-- E15. On average, how many days pass between a customer's consecutive orders?
-- Why: Sets the right timing for re-engagement emails and replenishment reminders.
WITH g AS (
  SELECT customer_id,
         julianday(order_date)
         - julianday(LAG(order_date) OVER (PARTITION BY customer_id
                                           ORDER BY order_date)) AS gap_days
  FROM orders
  WHERE order_status = 'Delivered'
)
SELECT ROUND(AVG(gap_days), 1) AS avg_days_between_orders,
       COUNT(gap_days)         AS repeat_orders_measured
FROM g
WHERE gap_days IS NOT NULL;

-- E16. Which products are low on stock but selling fast (last 90 days)?
-- Why: Prevents stock-outs on bestsellers. Data is as of 31 Oct 2026.
SELECT p.product_id, p.product_name, p.stock_qty,
       SUM(o.quantity) AS units_sold_90d
FROM products p
JOIN orders o ON p.product_id = o.product_id
WHERE o.order_status <> 'Cancelled'
  AND o.order_date >= date('2026-10-31', '-90 day')
GROUP BY p.product_id, p.product_name, p.stock_qty
HAVING p.stock_qty < 150
ORDER BY units_sold_90d DESC
LIMIT 10;

-- E17. Which products are dead stock: weak recent sales but money tied up in inventory?
-- Why: Tells finance and merchandising what to discount or liquidate.
SELECT p.product_id, p.product_name, p.category, p.stock_qty,
       COALESCE(SUM(o.quantity), 0)       AS units_sold_90d,
       ROUND(p.stock_qty * p.cost_price, 0) AS stock_value
FROM products p
LEFT JOIN orders o
       ON p.product_id = o.product_id
      AND o.order_status <> 'Cancelled'
      AND o.order_date >= date('2026-10-31', '-90 day')
GROUP BY p.product_id, p.product_name, p.category, p.stock_qty, p.cost_price
ORDER BY units_sold_90d ASC, stock_value DESC
LIMIT 10;

-- E18. Pareto check: what share of revenue comes from the top 20% of customers?
-- Why: Quantifies revenue concentration risk (the 80/20 rule).
WITH c AS (
  SELECT customer_id, SUM(total_amount) AS spend
  FROM orders WHERE order_status = 'Delivered'
  GROUP BY customer_id
),
r AS (
  SELECT customer_id, spend,
         ROW_NUMBER() OVER (ORDER BY spend DESC, customer_id) AS rn,
         COUNT(*)     OVER ()                                 AS n,
         SUM(spend)   OVER ()                                 AS total,
         SUM(spend)   OVER (ORDER BY spend DESC, customer_id
                            ROWS UNBOUNDED PRECEDING)         AS cum
  FROM c
)
SELECT MAX(n)                              AS total_customers,
       COUNT(*)                            AS top_20pct_customers,
       ROUND(100.0 * MAX(cum) / MAX(total), 1) AS pct_of_revenue
FROM r
WHERE rn <= 0.2 * n;

-- E19. How does each quarter compare with the same quarter last year?
-- Why: Year-over-year removes seasonality, so it is the fair growth measure. Q4 2026 only has October.
WITH q AS (
  SELECT strftime('%Y', order_date) AS yr,
         (CAST(strftime('%m', order_date) AS INT) + 2) / 3 AS qtr,
         SUM(total_amount) AS rev
  FROM orders WHERE order_status = 'Delivered'
  GROUP BY 1, 2
)
SELECT yr, qtr, ROUND(rev, 0) AS revenue,
       ROUND(100.0 * (rev - LAG(rev) OVER (PARTITION BY qtr ORDER BY yr))
             / LAG(rev) OVER (PARTITION BY qtr ORDER BY yr), 1) AS yoy_growth_pct
FROM q
ORDER BY yr, qtr;

-- E20. Which valuable repeat customers have gone quiet for 180+ days (churn risk)?
-- Why: A ready-made win-back list for the CRM team, sorted by value at risk.
SELECT c.customer_id, c.customer_name, c.city,
       COUNT(o.order_id)                       AS orders,
       MAX(o.order_date)                       AS last_order,
       CAST(julianday('2026-10-31') - julianday(MAX(o.order_date)) AS INT) AS days_inactive,
       ROUND(SUM(o.total_amount), 0)           AS lifetime_spend
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'Delivered'
GROUP BY c.customer_id, c.customer_name, c.city
HAVING COUNT(o.order_id) >= 2
   AND MAX(o.order_date) < date('2026-10-31', '-180 day')
ORDER BY lifetime_spend DESC
LIMIT 10;


-- ====================================================================
-- PROJECT 2: HEALTHCARE
-- ====================================================================

-- H1. What are the hospital's headline KPIs?
-- Why: One-line health check for management: volume, stay length, revenue, mortality and readmissions.
SELECT COUNT(*)                                   AS total_visits,
       COUNT(DISTINCT patient_id)                 AS unique_patients,
       ROUND(AVG(length_of_stay_days), 1)         AS avg_stay_days,
       ROUND(SUM(total_bill) / 1000000.0, 1)      AS revenue_million,
       ROUND(100.0 * SUM(CASE WHEN outcome = 'Deceased' THEN 1 ELSE 0 END) / COUNT(*), 2) AS mortality_pct,
       ROUND(100.0 * AVG(readmitted_30d), 1)      AS readmission_pct
FROM healthcare;

-- H2. How do departments compare on volume, stay length and revenue?
-- Why: Shows which departments drive revenue and which consume the most bed-days.
SELECT department,
       COUNT(*)                          AS visits,
       ROUND(AVG(length_of_stay_days),1) AS avg_stay_days,
       ROUND(AVG(total_bill), 0)         AS avg_bill,
       ROUND(SUM(total_bill), 0)         AS revenue
FROM healthcare
GROUP BY department
ORDER BY revenue DESC;

-- H3. What are the top 5 most common diagnoses and what do they cost?
-- Why: Guides capacity planning and specialist hiring.
SELECT diagnosis, department,
       COUNT(*)                           AS cases,
       ROUND(SUM(total_bill), 0)          AS revenue,
       ROUND(AVG(length_of_stay_days), 1) AS avg_stay_days
FROM healthcare
GROUP BY diagnosis, department
ORDER BY cases DESC
LIMIT 5;

-- H4. How are monthly admissions trending (with a 3-month moving average)?
-- Why: The moving average smooths noise so real demand changes stand out.
WITH m AS (
  SELECT strftime('%Y-%m', admission_date) AS month, COUNT(*) AS admissions
  FROM healthcare
  GROUP BY 1
)
SELECT month, admissions,
       ROUND(AVG(admissions) OVER (ORDER BY month
             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS moving_avg_3m
FROM m
ORDER BY month;

-- H5. Which age groups use the hospital most, and how do bills and stays differ?
-- Why: Supports targeted health camps and insurance product design.
SELECT CASE WHEN age <= 12 THEN '1. Child (0-12)'
             WHEN age <= 17 THEN '2. Teen (13-17)'
             WHEN age <= 39 THEN '3. Adult (18-39)'
             WHEN age <= 59 THEN '4. Middle (40-59)'
             ELSE '5. Senior (60+)' END   AS age_group,
       COUNT(*)                           AS visits,
       ROUND(AVG(total_bill), 0)          AS avg_bill,
       ROUND(AVG(length_of_stay_days),1)  AS avg_stay_days
FROM healthcare
GROUP BY 1
ORDER BY 1;

-- H6. What is the 30-day readmission rate by department?
-- Why: Readmissions are a key quality metric and are often penalised by insurers.
SELECT department,
       COUNT(*)                                   AS discharges,
       SUM(readmitted_30d)                        AS readmissions,
       ROUND(100.0 * SUM(readmitted_30d) / COUNT(*), 1) AS readmission_rate_pct
FROM healthcare
WHERE outcome <> 'Deceased'
GROUP BY department
ORDER BY readmission_rate_pct DESC;

-- H7. Which diagnoses have the highest mortality rate (with enough cases to be meaningful)?
-- Why: Flags clinical areas for quality review. HAVING avoids tiny-sample noise.
SELECT department, diagnosis,
       COUNT(*) AS cases,
       SUM(CASE WHEN outcome = 'Deceased' THEN 1 ELSE 0 END) AS deaths,
       ROUND(100.0 * SUM(CASE WHEN outcome = 'Deceased' THEN 1 ELSE 0 END) / COUNT(*), 2) AS mortality_pct
FROM healthcare
GROUP BY department, diagnosis
HAVING COUNT(*) >= 50
ORDER BY mortality_pct DESC
LIMIT 10;

-- H8. How do doctors compare on workload and success rate within their department?
-- Why: Fair performance review: compare doctors only against peers in the same department.
SELECT department, doctor_name,
       COUNT(*)                           AS patients,
       ROUND(AVG(length_of_stay_days), 1) AS avg_stay_days,
       ROUND(100.0 * SUM(CASE WHEN outcome IN ('Recovered','Improved') THEN 1 ELSE 0 END)
             / COUNT(*), 1)               AS success_rate_pct,
       RANK() OVER (PARTITION BY department
                    ORDER BY COUNT(*) DESC) AS workload_rank
FROM healthcare
GROUP BY department, doctor_name
ORDER BY department, workload_rank;

-- H9. How much of the bill do insurers cover, and how much is left for patients?
-- Why: Reveals which insurers reimburse well and where collection risk lies.
SELECT insurance_provider,
       COUNT(*)                              AS visits,
       ROUND(SUM(total_bill), 0)             AS billed,
       ROUND(SUM(insurance_covered), 0)      AS covered,
       ROUND(100.0 * SUM(insurance_covered) / SUM(total_bill), 1) AS coverage_pct,
       ROUND(SUM(total_bill - insurance_covered), 0) AS patient_payable
FROM healthcare
GROUP BY insurance_provider
ORDER BY coverage_pct DESC;

-- H10. How do Emergency, Planned and Referral admissions differ in cost, stay and outcome?
-- Why: Emergency cases need different staffing and bed planning.
SELECT admission_type,
       COUNT(*)                            AS visits,
       ROUND(AVG(total_bill), 0)           AS avg_bill,
       ROUND(AVG(length_of_stay_days), 1)  AS avg_stay_days,
       ROUND(100.0 * SUM(CASE WHEN outcome = 'Deceased' THEN 1 ELSE 0 END) / COUNT(*), 2) AS mortality_pct
FROM healthcare
GROUP BY admission_type
ORDER BY visits DESC;

-- H11. Which patients visit most often (5+ visits)?
-- Why: Frequent visitors may need a chronic-care programme, which also reduces repeat admissions.
SELECT patient_id, gender, city,
       COUNT(*)                       AS visits,
       COUNT(DISTINCT department)     AS departments,
       ROUND(SUM(total_bill), 0)      AS total_billed,
       MIN(admission_date)            AS first_visit,
       MAX(admission_date)            AS last_visit
FROM healthcare
GROUP BY patient_id, gender, city
HAVING COUNT(*) >= 5
ORDER BY visits DESC, total_billed DESC
LIMIT 10;

-- H12. Which cities do patients come from, and what share of revenue does each bring?
-- Why: Helps decide where to run outreach camps or open collection centres.
SELECT city,
       COUNT(*)                         AS visits,
       ROUND(SUM(total_bill), 0)        AS revenue,
       ROUND(100.0 * SUM(total_bill) / SUM(SUM(total_bill)) OVER (), 1) AS pct_of_revenue,
       RANK() OVER (ORDER BY SUM(total_bill) DESC) AS revenue_rank
FROM healthcare
GROUP BY city
ORDER BY revenue_rank;

-- H13. Which stays were unusually long (more than 2x the department average)?
-- Why: Long-stay outliers drive cost and block beds. Each one deserves a case review.
WITH x AS (
  SELECT visit_id, department, diagnosis,
         length_of_stay_days AS stay_days,
         AVG(length_of_stay_days) OVER (PARTITION BY department) AS dept_avg
  FROM healthcare
)
SELECT visit_id, department, diagnosis, stay_days,
       ROUND(dept_avg, 1)             AS dept_avg_stay,
       ROUND(stay_days - dept_avg, 1) AS extra_days
FROM x
WHERE stay_days > 2 * dept_avg
ORDER BY extra_days DESC
LIMIT 10;

-- H14. What is the male/female split in each department?
-- Why: Checks that services (for example Gynecology) and facilities match who is using them.
SELECT department,
       SUM(CASE WHEN gender = 'Male'   THEN 1 ELSE 0 END) AS male,
       SUM(CASE WHEN gender = 'Female' THEN 1 ELSE 0 END) AS female,
       ROUND(100.0 * SUM(CASE WHEN gender = 'Female' THEN 1 ELSE 0 END) / COUNT(*), 1) AS female_pct
FROM healthcare
GROUP BY department
ORDER BY female_pct DESC;

-- H15. Which months of the year are busiest (seasonality)?
-- Why: Plan staff leave, bed capacity and medicine stock around peak months.
SELECT strftime('%m', admission_date)  AS month_no,
       COUNT(*)                        AS admissions,
       RANK() OVER (ORDER BY COUNT(*) DESC) AS busiest_rank
FROM healthcare
GROUP BY strftime('%m', admission_date)
ORDER BY month_no;

-- H16. How are bed-days split across departments each year?
-- Why: Bed-days (total nights stayed) is the real measure of capacity used.
SELECT strftime('%Y', admission_date)        AS year,
       department,
       SUM(length_of_stay_days)              AS bed_days,
       ROUND(100.0 * SUM(length_of_stay_days)
             / SUM(SUM(length_of_stay_days)) OVER (PARTITION BY strftime('%Y', admission_date)), 1) AS pct_of_year
FROM healthcare
GROUP BY 1, 2
ORDER BY 1, bed_days DESC;

-- H17. How much money is patient-payable (not covered by insurance) in each city?
-- Why: Tells the billing team where to focus collections and payment-plan offers.
SELECT city,
       COUNT(*)                                       AS visits,
       ROUND(SUM(total_bill), 0)                      AS billed,
       ROUND(SUM(total_bill - insurance_covered), 0)  AS patient_payable,
       ROUND(100.0 * SUM(total_bill - insurance_covered) / SUM(total_bill), 1) AS payable_pct
FROM healthcare
GROUP BY city
ORDER BY patient_payable DESC;

-- H18. How does each department rank by revenue each year, and how is it growing year over year?
-- Why: Spots rising and declining service lines. 2026 is a partial year (to October).
WITH y AS (
  SELECT strftime('%Y', admission_date) AS yr, department,
         SUM(total_bill) AS rev
  FROM healthcare
  GROUP BY 1, 2
)
SELECT yr, department, ROUND(rev, 0) AS revenue,
       RANK() OVER (PARTITION BY yr ORDER BY rev DESC) AS rank_in_year,
       ROUND(100.0 * (rev - LAG(rev) OVER (PARTITION BY department ORDER BY yr))
             / LAG(rev) OVER (PARTITION BY department ORDER BY yr), 1) AS yoy_pct
FROM y
ORDER BY yr, rank_in_year;

-- H19. Which diagnoses cost more than the hospital-wide average bill?
-- Why: Highlights high-cost treatments for pricing and package design.
SELECT diagnosis,
       COUNT(*)                   AS cases,
       ROUND(AVG(total_bill), 0)  AS avg_bill
FROM healthcare
GROUP BY diagnosis
HAVING AVG(total_bill) > (SELECT AVG(total_bill) FROM healthcare)
ORDER BY avg_bill DESC;

-- H20. How many repeat visits happen within 30 days of the previous discharge, and are there data-quality problems?
-- Why: A true readmission check from raw dates. Negative gaps reveal overlapping stays, a classic data-quality finding.
WITH g AS (
  SELECT patient_id, visit_id,
         julianday(admission_date)
         - julianday(LAG(discharge_date) OVER (PARTITION BY patient_id
                                               ORDER BY admission_date)) AS gap_days
  FROM healthcare
)
SELECT COUNT(gap_days)                                            AS repeat_visits,
       SUM(CASE WHEN gap_days BETWEEN 0 AND 30 THEN 1 ELSE 0 END) AS within_30_days,
       SUM(CASE WHEN gap_days < 0 THEN 1 ELSE 0 END)              AS overlapping_stays_dq_issue
FROM g
WHERE gap_days IS NOT NULL;

