CREATE TABLE pizza_sales (
    pizza_id INTEGER PRIMARY KEY,
    order_id INTEGER ,
    pizza_name_id TEXT ,
    quantity INTEGER ,
    order_date DATE ,
    order_time TIME ,
    unit_price NUMERIC(10,2),
    total_price NUMERIC(10,2) ,
    pizza_size VARCHAR(10),
    pizza_category VARCHAR(50),
    pizza_ingredients TEXT,
    pizza_name TEXT
);

copy pizza_sales( pizza_id,  order_id,pizza_name_id, quantity,order_date, order_time,unit_price, total_price, pizza_size,pizza_category, pizza_ingredients,pizza_name)
FROM 'D:\WX22\Practise file\pizza_sales.csv'
DELIMITER ','
CSV HEADER;

SELECT * FROM pizza_sales;

-- KPI
-- 1. TOTAL REVENUE
SELECT SUM(unit_price) as tital_revenue
FROM pizza_sales;

-- 2. TOTAL ORDERS
SELECT COUNT(DISTINCT order_id) as total_orders
FROM pizza_sales;


SELECT * FROM pizza_sales;

-- 3. AVERAGE ORDER VALUE
SELECT CAST(CAST(SUM(total_price) AS DECIMAL(10,2)) /
CAST(COUNT(DISTINCT order_id) AS DECIMAL(10,2)) AS DECIMAL(10,2)) 
FROM pizza_sales;


--4. TOTAL PIZZAS SOLD
SELECT pizza_size,
SUM(quantity) as total_pizza_sold
FROM pizza_sales
GROUP BY pizza_size
ORDER BY total_pizza_sold DESC;

--5. AVERAGE PIZZAS PER ORDER
SELECT CAST(CAST(SUM(quantity) AS DECIMAL(10,2))/
CAST(COUNT(DISTINCT order_id) AS DECIMAL(10,2))
AS DECIMAL(10,2)) AS AVG_PIZZA_PER_ORDER 
FROM pizza_sales;

SELECT * FROM pizza_sales;

- --6 Total Pizzas Sold by Pizza Category
SELECT pizza_category,
sum(total_price) as total_pizza_catgeory,
EXTRACT (MONTH FROM order_date) as month_name
FROM pizza_sales
GROUP BY pizza_category,EXTRACT (MONTH FROM order_date)
ORDER BY total_pizza_catgeory DESC;


---- 7 Top 5 Pizzas by Revenue
SELECT pizza_name,
SUM(total_price) as top_5_pizza_revenue
FROM pizza_sales
GROUP BY pizza_name
ORDER BY  top_5_pizza_revenue DESC
LIMIT 5;

-- 8. Bottom 5 Pizzas by Revenue
SELECT pizza_name,
SUM(total_price) as bottom_5_revenue
FROM pizza_sales
GROUP BY pizza_name
ORDER BY bottom_5_revenue ASC
LIMIT 5;

-- 9 Top 5 Pizzas by Quantity
SELECT pizza_name,
SUM(quantity) as top_5_pizza_qunaity
FROM pizza_sales
GROUP BY pizza_name
ORDER BY top_5_pizza_qunaity DESC
LIMIT 5;

 --10. Bottom 5 Pizzas by Quantity
SELECT pizza_name,
SUM(quantity) as botom_pizza_5
FROM pizza_sales
GROUP BY pizza_name
ORDER BY botom_pizza_5 ASC
LIMIT 5;

--11. Top 5 Pizzas by Total Orders
SELECT pizza_name,
SUM(total_price) as total_pizza_revenue,
COUNT(DISTINCT order_id) as top_5_pizza
FROM pizza_sales
GROUP BY pizza_name 
ORDER BY total_pizza_revenue DESC
LIMIT 5;


-- 12. Bottom 5 Pizzas by Total Orders
SELECT pizza_name,
SUM(quantity) as total_qunatity,
COUNT(DISTINCT order_id) as unique_pizza
FROM pizza_sales
GROUP BY pizza_name
ORDER BY total_qunatity ASC
LIMIT 5;


--13 top 5 classic pizza_categoty
SELECT pizza_name,pizza_category,
SUM(total_price) as top_5_classic_category
FROM pizza_sales
WHERE pizza_category = 'Classic'
GROUP BY pizza_name,pizza_category
ORDER BY top_5_classic_category DESC
LIMIT 5;

