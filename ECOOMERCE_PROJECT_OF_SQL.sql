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

COPY customers(customer_id,customer_name,email, gender, age, city, state,signup_date,acquisition_channel)
FROM 'D:\SQL_PROJECT_\customers.csv'
DELIMITER ','
CSV HEADER ;

COPY products(product_id,product_name, category, brand, price,cost_price, stock_qty)
FROM 'D:\SQL_PROJECT_\products.csv'
DELIMITER ','
CSV HEADER;

COPY orders(  order_id,customer_id, product_id,order_date,quantity,discount_pct,total_amount,payment_method,order_status)
FROM 'D:\SQL_PROJECT_\orders.csv'
DELIMITER ','
CSV HEADER;

SELECT * FROM customers;
SELECT * FROM  products;
SELECT * FROM orders;

--BUSINESS QUESTION 
--Q1 CACLATE TOTAL REVENUE
SELECT SUM(total_amount) as total_revenue
FROM  orders;

--q2 count total orders
SELECT gender,
count(customer_id) as total_orders
FROM customers
GROUP BY gender
ORDER BY total_orders desc;  -- male total orders 252 ,female 248

--Q3 COUNT TOTAL ORDERS
SELECT count(*) as total_orders  --total order of  2600
FROM orders;

--Q4 COUNT TOTAL PRODUCT
SELECT count(*) as total_product  -- total product is 41
FROM products;

--Q5 CALCULATE TOTAL AVE OF ORDERS  -- avrage upi amount IS SHIPPED 21443,CANCELEED 18536,
SELECT payment_method,order_status,  -- DELIVERED 17590 AND RETUNED 15003
round(avg(total_amount),2) as total_avrerage
FROM  orders
WHERE payment_method = 'UPI'
GROUP BY payment_method,order_status
ORDER BY total_avrerage desc;  


--q6 FIND TOP 5 PRODUCT SELLING 
SELECT product_name,  -- top 5 sellling product webcam,blutooth,smartphone max,
sum(price) as total_price  -- tablet calssuc , headphone max
FROM products
GROUP BY product_name
ORDER BY total_price DESC
LIMIT 5 ;

SELECT * FROM customers;
SELECT * FROM  products;
SELECT * FROM orders;

--	Q7 FIND THE TOTAL AMOUNT OF ORDER STATUS
SELECT p.product_name,o.product_id, -- TOP 5 PRODUC AND DELIVERD  AMOUNT
o.order_status,                       --1 Smartphone Max 5085426.50,2Webcam Max 4782606.00,
SUM(o.total_amount) as total_amount_status --Bluetooth Speaker Pro 4623528.00 ,4 Tablet Classic  3920100.00
FROM products p                            -- 5 Headphones Max 2499257.50
JOIN orders o
ON o.product_id=p.product_id
GROUP BY p.product_name,p.product_id,o.product_id,
o.order_status
ORDER BY total_amount_status DESC
LIMIT 5;

SELECT * FROM  products;
SELECT * FROM orders;

--Q8 FIND THE TOTAL REVNUE OF CATEGORY
SELECT o.product_id,p.product_id,p.product_name,
sum(p.price) as total_revenue_ctegory
FROM  products p
join orders o
ON o.product_id=p.product_id
GROUP BY o.product_id,p.product_id,p.product_name
ORDER BY total_revenue_ctegory DESC
limit 10;

SELECT * FROM customers;
SELECT * FROM  products;
SELECT * FROM orders;
--Q9 FIND TOP 5 CUSTOMER NAME OF REVENUE
SELECT c.customer_name,c.gender,c.customer_id,o.customer_id,
SUM(o.total_amount) as top_5_custoemt_revunue
FROM customers c
JOIN orders o
ON o.customer_id=c.customer_id
GROUP BY c.customer_name,c.gender,c.customer_id,o.customer_id
ORDER BY top_5_custoemt_revunue
limit 5;  -- TOP 5 CUSTOEMRS Deepak Chopra,Divya Joshi,Amit Jain,Vikram Nair,Amit Nair

SELECT * FROM  products;
SELECT * FROM orders;      

--Q10 CACLLATE TOTAL REVUNUE MONTH  
SELECT o.order_status ,DATE_TRUNC('MONTH' , o.order_date) as month_name,
SUM(p.cost_price) as total_cost_price
FROM products p
JOIN  orders o
on o.product_id=p.product_id
GROUP BY o.order_status, DATE_TRUNC('MONTH', o.order_date)
ORDER BY total_cost_price DESC
LIMIT 10;

SELECT * FROM customers;
SELECT * FROM orders;

--11 FIND TOP 5 PRODUCT OF TALT_PRICE
SELECT c.city,
sum(o.total_amount) as top_5_city_revenue
FROM customers c
JOIN  orders o
ON c.customer_id=o.customer_id
GROUP BY c.city
ORDER BY top_5_city_revenue DESC
limit 5;  