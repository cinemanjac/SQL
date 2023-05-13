/*
Business Analysis on a delivery service company
SQL type: PostgreSQL
*/


---------------------------------------------------------------------------------------------
--1.General revenue metrics: daily revenue, cumulative revenue, revenue growth

SELECT date,
       revenue,
       SUM(revenue) OVER (ORDER BY date) AS total_revenue,
       ROUND(100 * (revenue - LAG(revenue, 1) OVER (ORDER BY date))::DECIMAL / LAG(revenue, 1) OVER (ORDER BY date),
             2) AS revenue_change
FROM   (SELECT creation_time::DATE AS date,
               SUM(price) AS revenue
        FROM   (SELECT creation_time,
                       UNNEST(product_ids) AS product_id
                FROM   orders
                WHERE  order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')) t1
        LEFT JOIN products USING (product_id)
        GROUP BY date) t2


---------------------------------------------------------------------------------------------
--2.ARPU (Average Revenue Per User), ARPPU (Average Revenue Per Paying User), AOV (Average Order Value)

SELECT date,
       ROUND(revenue::DECIMAL / users, 2) AS arpu,
       ROUND(revenue::DECIMAL / paying_users, 2) AS arppu,
       ROUND(revenue::DECIMAL / orders, 2) AS aov
FROM   (SELECT creation_time::DATE AS date,
               COUNT(DISTINCT order_id) AS orders,
               SUM(price) AS revenue
        FROM   (SELECT order_id,
                       creation_time,
                       UNNEST(product_ids) AS product_id
                FROM   orders
                WHERE  order_id NOT IN (SELECT order_id
                                        FROM   user_actions
                                        WHERE  action = 'cancel_order')) t1
        LEFT JOIN products USING(product_id)
        GROUP BY date) t2
LEFT JOIN 	   (SELECT time::DATE AS date,
                      COUNT(DISTINCT user_id) AS users
               FROM   user_actions
               GROUP BY date) t3
USING (date)
LEFT JOIN      (SELECT time::DATE AS date,
                      COUNT(DISTINCT user_id) AS paying_users
               FROM   user_actions
               WHERE  order_id NOT IN (SELECT order_id
                                       FROM   user_actions
                                       WHERE  action = 'cancel_order')
               GROUP BY date) t4
USING (date)
ORDER BY date


---------------------------------------------------------------------------------------------
--3.Calculate the daily revenue from new user orders and determine its proportion to the total revenue from all user orders.

WITH daily_revenue AS
(
SELECT date,
       SUM(price) AS revenue
FROM   (SELECT creation_time::DATE AS date,
               UNNEST(product_ids) AS product_id
        FROM   orders
        WHERE  order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')) t1
JOIN products USING(product_id)
GROUP BY date
),

orders_value AS
(
SELECT order_id,
       SUM(price) AS order_value
FROM   (SELECT order_id,
               UNNEST(product_ids) AS product_id
        FROM   orders
        WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE  action = 'cancel_order')) t2
	    JOIN products USING(product_id)
GROUP BY order_id
),

new_users_orders AS
(
SELECT time::DATE AS date,
       user_actions.user_id,
       order_id
FROM   user_actions
JOIN	(SELECT user_id,
                MIN(time::DATE) AS date
         FROM user_actions
         GROUP BY user_id) t3
ON user_actions.user_id = t3.user_id
AND user_actions.time::DATE = t3.date
)

SELECT date,
       revenue,
       new_users_revenue,
       ROUND(new_users_revenue / revenue * 100, 2) AS new_users_revenue_share,
       100 - ROUND(new_users_revenue / revenue * 100, 2) AS old_users_revenue_share
FROM   (SELECT date,
               SUM(order_value) AS new_users_revenue
        FROM   (SELECT date,
                       user_id,
                       order_id,
                       order_value
                FROM   new_users_orders
				JOIN   orders_value USING(order_id)) t4
        GROUP BY date) t5
JOIN daily_revenue USING(date)


---------------------------------------------------------------------------------------------
--4.What products are in high demand and bring us the main income.
--Calculating total revenue for each product and share of revenue from the sales of this product in the total revenue.

SELECT product_name,
       SUM(revenue) AS revenue,
       SUM(share_in_revenue) AS share_in_revenue
FROM   (SELECT CASE
			   WHEN ROUND(100 * revenue / SUM(revenue) OVER (), 2) >= 0.5 THEN name
               ELSE 'OTHER'
			   END AS product_name,
               revenue,
               ROUND(100 * revenue / SUM(revenue) OVER (), 2) AS share_in_revenue
        FROM   (SELECT name,
                       SUM(price) AS revenue
                FROM   (SELECT order_id,
                               UNNEST(product_ids) AS product_id
                        FROM   orders
                        WHERE  order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')) t1
                LEFT JOIN products USING(product_id)
                GROUP BY name) t2) t3
GROUP BY product_name
ORDER BY revenue DESC


---------------------------------------------------------------------------------------------
--5.For each day, the economic metrics to be tracked include revenue, costs, tax, profit, and the share of gross profit in revenue.
--  These metrics will also be monitored over time as running totals.			  					  

SELECT date,
       revenue,
       costs,
       tax,
       gross_profit,
       total_revenue,
       total_costs,
       total_tax,
       total_gross_profit,
       round(gross_profit / revenue * 100, 2) AS gross_profit_ratio,
       round(total_gross_profit / total_revenue * 100, 2) AS total_gross_profit_ratio
	   
FROM   (SELECT date,
               revenue,
               costs,
               tax,
               (revenue - costs - tax) AS gross_profit,
               SUM(revenue) OVER (ORDER BY date) AS total_revenue,
               SUM(costs) OVER (ORDER BY date) AS total_costs,
               SUM(tax) OVER (ORDER BY date) AS total_tax,
               SUM(revenue - costs - tax) OVER (ORDER BY date) AS total_gross_profit
		
				/* Table of product TAX costs and revenue.
				   The standard tax rate for goods is 20%, but there is a list of products that have a reduced tax rate of 10% */
		
        FROM   (SELECT date,
                       SUM(price) AS revenue,
                       SUM(tax)::INT AS tax
                FROM   (SELECT date,
                               price,
                               CASE
							   WHEN name IN ('Sugar', 'Cookies', 'Crackers', 'Sunflower seeds', 
											 'Flaxseed oil', 'Grapes', 'Olive oil', 
											 'Watermelon', 'Bread', 'Yogurt', 'Cream', 'Buckwheat', 
											 'Oatmeal', 'Pasta', 'Lamb', 'Oranges', 
											 'Bagels', 'Bread', 'Peas', 'Sour cream', 'Smoked fish', 
											 'Flour', 'Sprats', 'Sausages', 'Pork', 'Rice', 
											 'Sesame oil', 'Condensed milk', 'Pineapple', 'Beef', 
											 'Salt', 'Dried fish', 'Sunflower oil', 'Apples', 
											 'Pears', 'Flatbread', 'Milk', 'Chicken', 'Lavash', 'Waffles', 'Tangerines') THEN ROUND((price::DECIMAL / 110) * 10, 2)
                                ELSE ROUND((price::DECIMAL / 120) * 20, 2)
								END AS tax
                         FROM   (SELECT creation_time::DATE AS date,
                                       	UNNEST(product_ids) AS product_id
                                 FROM   orders
                                 WHERE  order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')) t1
						 JOIN products USING(product_id)) t5
                 GROUP BY date) revenue_tax
		
				/* We are going to join a table with all other costs.
		
				   In order to do that we make 2 separate tables: one with courier pay and their bonuses,
				   another one with overhead costs and the cost to make each order.
		
				   Joining a table with courier pay and bonuses:
				   In August: the company pays 150 to a courier for each delivered order. An additional 400 bonus if 5 or more orders delivered the same day 
				   In September: 150 for each order, 500 bonus for 5 or more orders delivered the same day */
		
		JOIN	(SELECT date,
                        daily_courier_pay + daily_courier_bonus + daily_packing_price + fixed_cost AS costs
                 FROM   (SELECT date,
                                SUM(courier_pay) AS daily_courier_pay,
                                SUM(bonus_price) AS daily_courier_bonus
                         FROM   (SELECT date,
                                        orders_count*150 AS courier_pay,
                                        CASE
										WHEN DATE_PART('month', date) = 08 AND orders_count >= 5 THEN 400
                                        WHEN date_part('month', date) = 09 AND orders_count >= 5 THEN 500
                                        ELSE 0
										END AS bonus_price
                                 FROM   (SELECT time::DATE AS date,
                                                courier_id,
                                                COUNT(order_id) orders_count
										 FROM courier_actions
										 WHERE action = 'deliver_order'
										 GROUP BY 1,2) t2) t3
						 GROUP BY date) couriers_cost
				 
				 /* Joining a table with overhead costs: The fixed daily costs to run the business operations in August = 120000, in September = 150000.
				 						   				 The cost to prepare one order in August = 140, in September = 115 */
				 
				  JOIN	(SELECT date,
								CASE
								WHEN DATE_PART('month',date) = 08 THEN orders_count*140
								ELSE orders_count*115
								END AS daily_packing_price,
								CASE
								WHEN DATE_PART('month',date) = 08 THEN 120000
								ELSE 150000
								END AS fixed_cost
						 FROM	(SELECT time::DATE AS date,
        								COUNT(order_id) AS orders_count
								 FROM courier_actions
								 WHERE action = 'accept_order'
								 AND order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
								 GROUP BY date) t4) daily_overheads
				  USING(date)) daily_costs
		USING(date)) t6
		
		
---------------------------------------------------------------------------------------------