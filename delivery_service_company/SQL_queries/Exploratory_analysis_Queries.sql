/*
Business Analysis on a delivery service company
SQL type: PostgreSQL
*/


---------------------------------------------------------------------------------------------
--1.oldest users by sex

SELECT
  sex,
  DATE_PART('year', MAX(AGE(birth_date))) AS max_age
FROM
  users
GROUP BY
  sex
ORDER BY
  max_age


---------------------------------------------------------------------------------------------
--2.grouping users by age

SELECT
  DATE_PART('year', AGE(birth_date)) AS age,
  COUNT(user_id) AS users_count
FROM
  users
GROUP BY
  age
ORDER BY
  age


---------------------------------------------------------------------------------------------
--3.how many orders were made, and how many orders were canceled in each month

SELECT
  DATE_TRUNC('month', time) AS month,
  action,
  COUNT(order_id) AS orders_count
FROM
  user_actions
GROUP BY
  month, action
ORDER BY
  month, action


---------------------------------------------------------------------------------------------
--4.top 3 couriers in August by delivered orders

SELECT
  courier_id,
  COUNT(DISTINCT order_id) AS delivered_orders
FROM
  courier_actions
WHERE
  action = 'deliver_order'
  AND DATE_PART('month', time) = 8
GROUP BY
  courier_id
ORDER BY
  delivered_orders desc
LIMIT 3


---------------------------------------------------------------------------------------------
--5.how many clients made at least 1 order during the last week

SELECT
  COUNT(DISTINCT user_id) AS users_count
FROM
  user_actions
WHERE
  action = 'create_order'
  AND time > (SELECT MAX(time) FROM user_actions) - INTERVAL '1 week'


---------------------------------------------------------------------------------------------
--6.how many orders did each user made, and compare it with the average number of orders per user

WITH CTE_table AS
    (SELECT user_id,
        COUNT(order_id) AS orders_count
    FROM user_actions
    WHERE action='create_order'
    GROUP BY user_id)
SELECT user_id,
    orders_count,
    ROUND((SELECT AVG(orders_count) FROM CTE_table), 2) AS orders_avg,
    orders_count - ROUND((SELECT AVG(orders_count) FROM CTE_table), 2) AS orders_difference
FROM CTE_table
ORDER BY user_id
LIMIT 1000


---------------------------------------------------------------------------------------------
--7.Apply a 15% discount to products whose original price is more than £50 above the average price of all products,
--	and apply a 10% discount to products whose original price is £50 or less below the average price of all products

WITH avg_price AS 
    (SELECT ROUND(AVG(price), 2)
    FROM
    products)
SELECT
  product_id,
  name,
  price,
  CASE
    WHEN price >= (SELECT * FROM avg_price) + 50 THEN price * 0.85
    WHEN price <= (SELECT * FROM avg_price) - 50 THEN price * 0.9
    ELSE price
  END AS new_price
FROM
  products
ORDER BY
  price DESC


---------------------------------------------------------------------------------------------
--8.10 most commonly bought products

SELECT
  UNNEST(product_ids) AS product_id,
  COUNT(*) AS times_purchased
FROM
  orders
GROUP BY
  product_id
ORDER BY
  times_purchased DESC
LIMIT 10


---------------------------------------------------------------------------------------------
--9.What is the average number of products that each user orders?

SELECT
  user_id,
  ROUND(AVG(ARRAY_LENGTH(product_ids, 1)), 2) AS avg_order_size
FROM
    (SELECT
      user_id,
      order_id
    FROM
      user_actions
    WHERE
      order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')) t1
LEFT JOIN orders USING(order_id)
GROUP BY
  user_id
ORDER BY
  user_id
limit 1000


---------------------------------------------------------------------------------------------
--10.price of each order

SELECT
  order_id,
  SUM(price) AS order_price
FROM
    (SELECT
      order_id,
      product_ids,
      UNNEST(product_ids) AS product_id
    FROM
      orders) t1
LEFT JOIN products using(product_id)
GROUP BY
  order_id
ORDER BY
  order_id
limit 1000


---------------------------------------------------------------------------------------------
--11.for each user we are going to show the following metrics:
--	how many orders each user made,
--	how many items on average did each user order
--	total value of orders per each user
--	average value of orders per each user
--	minimum and maximum value of each users orders

SELECT
  user_id,
  COUNT(order_id) AS orders_count,
  ROUND(AVG(order_size), 2) AS avg_order_size,
  SUM(order_price) AS sum_order_value,
  ROUND(AVG(order_price), 2) AS avg_order_value,
  MIN(order_price) AS min_order_value,
  MAX(order_price) AS max_order_value
FROM
    (
    SELECT
      user_id,
      order_id,
      ARRAY_LENGTH(product_ids, 1) AS order_size
    FROM
        (SELECT
          user_id,
          order_id
        FROM
          user_actions
        WHERE
          order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')) t1
    LEFT JOIN orders USING(order_id)
    ) t2
LEFT JOIN
    (
    SELECT
      order_id,
      SUM(price) AS order_price
    FROM
        (SELECT
          order_id,
          product_ids,
          UNNEST(product_ids) AS product_id
        FROM
          orders
        WHERE
          order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')) t3
    LEFT JOIN products USING(product_id)
    GROUP BY order_id
    ) t4
USING (order_id)
GROUP BY user_id
ORDER BY user_id
LIMIT 1000


---------------------------------------------------------------------------------------------
--12.the average orders cancelation rate for each gender

SELECT COALESCE(sex, 'unknown') AS sex,
       ROUND(AVG(cancel_rate), 3) AS avg_cancel_rate
FROM   (SELECT user_id,
               sex,
               COUNT(DISTINCT order_id) FILTER (WHERE action = 'cancel_order')::DECIMAL / COUNT(distinct order_id) AS cancel_rate
        FROM user_actions
        LEFT JOIN users USING(user_id)
        GROUP BY user_id, sex) t
GROUP BY sex
ORDER BY sex


---------------------------------------------------------------------------------------------
--13.10 customer orders that have the longest delivery times

SELECT order_id
FROM   (SELECT order_id,
               time - creation_time
        FROM   courier_actions
        JOIN orders USING(order_id)
        WHERE  action = 'deliver_order'
        ORDER BY 2 DESC) t1
LIMIT 10


---------------------------------------------------------------------------------------------
--14.replace product IDs in each order to product names

SELECT order_id,
       ARRAY_AGG(name) AS product_names
FROM   (SELECT order_id,
               UNNEST(product_ids) AS product_id
        FROM   orders) q1
JOIN products USING(product_id)
GROUP BY order_id
LIMIT 1000


---------------------------------------------------------------------------------------------
--15.Let's track the cumulative daily increase in the number of orders.

SELECT date,
       orders_count,
       SUM(orders_count) OVER (ORDER BY date) AS orders_daily_growth
FROM   (SELECT DATE(creation_time) as date,
               COUNT(order_id) AS orders_count
        FROM   orders
        WHERE  order_id NOT IN (SELECT order_id FROM user_actions WHERE  action = 'cancel_order')
        GROUP BY date) t


---------------------------------------------------------------------------------------------
--16.Let's analyze the time interval between orders for each user.

SELECT user_id,
       order_id,
       ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY time) AS order_number,
       time - LAG(time, 1) OVER (PARTITION BY user_id ORDER BY time) AS time_diff
FROM   user_actions
WHERE  order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
ORDER BY user_id, order_number
LIMIT 1000


---------------------------------------------------------------------------------------------
--17.Let's identify the couriers who delivered more orders than the average number of orders delivered by all couriers in September.
--	using CASE together with WINDOW FUNCTIONS

SELECT courier_id,
       delivered_orders,
       ROUND(AVG(delivered_orders) OVER(), 2) avg_delivered_orders,
       CASE
	   	WHEN delivered_orders > AVG(delivered_orders) OVER() THEN 1
		ELSE 0
	   END AS is_above_avg
FROM   (SELECT courier_id,
               COUNT(order_id) delivered_orders
        FROM   courier_actions
        WHERE  DATE_PART('month', time) = 9
           AND action = 'deliver_order'
        GROUP BY courier_id) t1
ORDER BY courier_id


---------------------------------------------------------------------------------------------
--18.Using WINDOW FUNCTIONS and FILTER, the query will populate all products, their prices, and add two columns -
--	one showing the average price of all products and the other showing the average price of all products excluding the most expensive one.
--	This can be a useful way to compare the prices of different products and see how they compare to the overall average
--	and to the average without the outlier of the most expensive product.

SELECT product_id,
       name,
       price,
       ROUND(AVG(price) OVER (), 2) AS avg_price,
       ROUND(AVG(price) FILTER (WHERE price != (SELECT MAX(price) FROM products)) OVER (), 2) AS avg_price_filtered
FROM products
ORDER BY price DESC, product_id


---------------------------------------------------------------------------------------------
--19.Providing  a breakdown of the number of orders placed and the number of orders cancelled by each user over a period of time,
--	as well as the cancellation rate for each user.

SELECT user_id,
       order_id,
       action,
       time,
       created_orders,
       canceled_orders,
       ROUND(canceled_orders::DECIMAL / created_orders, 2) AS cancel_rate
FROM   (SELECT user_id,
               order_id,
               action,
               time,
               COUNT(order_id) FILTER (WHERE action = 'create_order') OVER (PARTITION BY user_id
                                                                             ORDER BY time) AS created_orders,
               COUNT(order_id) FILTER (WHERE action = 'cancel_order') OVER (PARTITION BY user_id
                                                                            ORDER BY time) AS canceled_orders
        FROM   user_actions) t
ORDER BY user_id, order_id, time
LIMIT 1000


---------------------------------------------------------------------------------------------
--20.A list of couriers who have worked with us for more than 10 days, along with the number of orders each of them has taken.

SELECT DISTINCT courier_id,
                DATE_PART('days', (max_date - min_date)) AS days_employed,
                delivered_orders
FROM   (SELECT courier_id,
               MIN(time) OVER (PARTITION BY courier_id) AS min_date,
               MAX(time) OVER() AS max_date,
               COUNT(order_id) FILTER (WHERE action = 'deliver_order') OVER (PARTITION BY courier_id) AS delivered_orders
        FROM   courier_actions) t1
WHERE  (max_date::DATE - min_date::DATE) >= 10
ORDER BY days_employed DESC, courier_id


---------------------------------------------------------------------------------------------
--21.The revenue generated on a daily basis, along with a daily revenue growth, and the corresponding percentage of growth

SELECT date,
       daily_revenue,
       revenue_growth_abs,
       ROUND(COALESCE(revenue_growth_abs::DECIMAL / LAG(daily_revenue) OVER (ORDER BY date) * 100, 0), 1) AS revenue_growth_percentage
FROM   (
		SELECT date,
               daily_revenue,
               COALESCE(daily_revenue - LAG(daily_revenue) OVER (ORDER BY date), 0) AS revenue_growth_abs
        FROM   (SELECT DATE(creation_time) AS date,
                       SUM(price) daily_revenue
                FROM   (SELECT creation_time,
                               order_id,
                               UNNEST(product_ids) AS product_id
                        FROM   orders
                        WHERE  order_id NOT IN (SELECT order_id
                                                FROM   user_actions
                                                WHERE  action = 'cancel_order')) t1
				JOIN products USING(product_id)
                GROUP BY 1) t2
	   ) t3
---------------------------------------------------------------------------------------------