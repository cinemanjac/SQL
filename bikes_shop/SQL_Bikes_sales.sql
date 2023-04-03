/*
Bikes Sales in a small chain of stores
SQL type: TSQL
*/


-- We will create a VIEW that includes all the required information from various tables by joining them together, which will be used for our work

CREATE VIEW main_table
AS
SELECT  ord.order_id,
		CONCAT(cus.first_name, ' ', cus.last_name) AS customers,
		cus.city,
		cus.state,
		ord.order_date,
		SUM(ite.quantity) AS total_units,
		SUM(ite.quantity * ite.list_price) AS revenue,
		pro.product_name,
		cat.category_name,
		sto.store_name,
		CONCAT(sta.first_name, ' ', sta.last_name) AS sales_rep
FROM sales.orders ord
JOIN sales.customers cus
ON ord.customer_id = cus.customer_id
JOIN sales.order_items ite
ON ord.order_id = ite.order_id
JOIN production.products pro
ON ite.product_id = pro.product_id
JOIN production.categories cat
ON pro.category_id = cat.category_id
JOIN sales.stores sto
ON ord.store_id = sto.store_id
JOIN sales.staffs sta
ON ord.staff_id = sta.staff_id
GROUP BY 
		ord.order_id,
		CONCAT(cus.first_name, ' ', cus.last_name),
		cus.city,
		cus.state,
		ord.order_date,
		pro.product_name,
		cat.category_name,
		sto.store_name,
		CONCAT(sta.first_name, ' ', sta.last_name)


-- Total revenues by date

SELECT  order_date,
		SUM(revenue) AS revenue
FROM main_table
GROUP BY order_date
ORDER BY order_date


-- Total revenues by year

SELECT  DATEPART(year, order_date) AS Year,
		SUM(revenue) AS revenue
FROM main_table
GROUP BY DATEPART(year, order_date)
ORDER BY DATEPART(year, order_date)


-- Total revenues by year,month

SELECT  DATEPART(year, order_date) AS Year,
		DATENAME(month, order_date) AS Month,
		DATEPART(month, order_date) AS month_number,
		SUM(revenue) AS revenue
FROM main_table
GROUP BY DATEPART(year, order_date), DATENAME(month, order_date), DATEPART(month, order_date)
ORDER BY DATEPART(year, order_date), DATEPART(month, order_date)


-- Revenues by state, store

SELECT	state, store_name, SUM(revenue) as revenue
FROM main_table
GROUP BY state, store_name
ORDER BY SUM(revenue)


-- Revenue by category

SELECT	category_name, SUM(revenue) AS revenue
FROM main_table
GROUP BY category_name
ORDER BY SUM(revenue)


-- Top customers by revenue

SELECT customers, SUM(revenue) AS revenue
FROM main_table
GROUP BY customers


-- Top sales representatives

SELECT sales_rep, SUM(revenue) AS revenue
FROM main_table
GROUP BY sales_rep