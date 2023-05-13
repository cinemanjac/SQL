/*
Business Analysis on a delivery service company
SQL type: PostgreSQL
*/


---------------------------------------------------------------------------------------------
--1.Number of new users and new couriers, as well as the total number of users and couriers on the current date.

SELECT start_date AS date,
       new_users,
       new_couriers,
       (SUM(new_users) OVER (ORDER BY start_date))::INT AS total_users,
       (SUM(new_couriers) OVER (ORDER BY start_date))::INT AS total_couriers
FROM    (
		SELECT start_date,
               COUNT(courier_id) AS new_couriers
        FROM   (SELECT courier_id,
                       MIN(time::DATE) AS start_date
                FROM   courier_actions
                GROUP BY courier_id) t1
        GROUP BY start_date
		) t2
LEFT JOIN ( 
		   SELECT start_date,
           		  COUNT(user_id) AS new_users
           FROM   (SELECT user_id,
                          MIN(time::DATE) AS start_date
                   FROM   user_actions
                   GROUP BY user_id) t3
           GROUP BY start_date) t4
USING (start_date)


---------------------------------------------------------------------------------------------
--2.Number of paying users and active couriers, as well as the percentage of paying users and active couriers out of the total on the current date.
--	Paying users refer to those who placed an order on a particular day, while active couriers refer to those who delivered an order on a particular day

SELECT date,
       paying_users,
       active_couriers,
       ROUND(100 * paying_users::DECIMAL / total_users, 2) AS paying_users_share,
       ROUND(100 * active_couriers::DECIMAL / total_couriers, 2) AS active_couriers_share
FROM   (
	    SELECT start_date AS date,
               new_users,
               new_couriers,
               (SUM(new_users) OVER (ORDER BY start_date))::INT AS total_users,
               (SUM(new_couriers) OVER (ORDER BY start_date))::INT AS total_couriers
        FROM   (SELECT start_date,
                       COUNT(courier_id) AS new_couriers
                FROM   (SELECT courier_id,
                               MIN(time::DATE) AS start_date
                        FROM   courier_actions
                        GROUP BY courier_id) t1
                GROUP BY start_date) t2
        LEFT JOIN (SELECT start_date,
                          COUNT(user_id) AS new_users
                   FROM   (SELECT user_id,
                                  MIN(time::DATE) AS start_date
                           FROM   user_actions
                           GROUP BY user_id) t3
                   GROUP BY start_date) t4
		USING (start_date)
		) t5
		
LEFT JOIN (SELECT time::DATE AS date,
                  COUNT(DISTINCT courier_id) AS active_couriers
           FROM   courier_actions
           WHERE  order_id IN (SELECT order_id FROM courier_actions WHERE  action = 'deliver_order')
           GROUP BY date) t6
USING (date)
LEFT JOIN (SELECT time::DATE AS date,
           COUNT(DISTINCT user_id) AS paying_users
           FROM user_actions
		   WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE  action = 'cancel_order')
           GROUP BY date) t7
USING (date)


---------------------------------------------------------------------------------------------
--3.Let's examine the number of paying users who placed more than one order per day.

SELECT date,
       ROUND(100 * single_order_users::DECIMAL / paying_users, 2) AS single_order_users_share,
       100 - ROUND(100 * single_order_users::DECIMAL / paying_users, 2) AS several_orders_users_share
FROM   (SELECT time::DATE AS date,
               COUNT(DISTINCT user_id) AS paying_users
        FROM   user_actions
        WHERE  order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
        GROUP BY date) t1
LEFT JOIN (SELECT date,
                  COUNT(user_id) AS single_order_users
           FROM   (SELECT time::DATE AS date,
                          user_id,
                          COUNT(DISTINCT order_id) AS user_orders
                   FROM   user_actions
                   WHERE  order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
                   GROUP BY date, user_id
				   HAVING COUNT(DISTINCT order_id) = 1) t2
           GROUP BY date) t3
USING (date)
ORDER BY date


---------------------------------------------------------------------------------------------
--4.Now let's try to roughly estimate the workload on our couriers and find out how many orders and users on average each of them has to deal with.

SELECT date,
       ROUND(paying_users::DECIMAL / active_couriers, 2) AS users_per_courier,
       ROUND(orders::DECIMAL / active_couriers, 2) AS orders_per_courier
FROM   (SELECT time::DATE AS date,
               COUNT(DISTINCT courier_id) AS active_couriers
        FROM courier_actions
        WHERE order_id IN (SELECT order_id FROM courier_actions WHERE action = 'deliver_order')
        GROUP BY date) t1
LEFT JOIN (SELECT time::DATE AS date,
                  COUNT(DISTINCT user_id) AS paying_users
           FROM user_actions
           WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE  action = 'cancel_order')
           GROUP BY date) t2
USING(date)
LEFT JOIN (SELECT creation_time::DATE AS date,
           COUNT(order_id) AS orders
           FROM orders
           WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
           GROUP BY 1) t3
USING(date)
ORDER BY date


---------------------------------------------------------------------------------------------
--5.Let's calculate another useful indicator that characterizes the quality of courier work -
--	on average, how many minutes did couriers take to deliver their orders for each day.

SELECT date,
       ROUND(AVG(delivery_time)) AS minutes_to_deliver
FROM   (SELECT order_id,
               MAX(time::DATE) AS date,
               EXTRACT(EPOCH FROM MAX(time) - MIN(time))/60 AS delivery_time
        FROM courier_actions
        WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
        GROUP BY order_id) t
GROUP BY date
ORDER BY date


---------------------------------------------------------------------------------------------
--6.Let's estimate the hourly workload on our service, find out during which hours users place the most orders,
--	and analyze how the proportion of cancellations changes depending on the time of order placement.

SELECT hour,
       successful_orders,
       canceled_orders,
       ROUND(canceled_orders::DECIMAL / (canceled_orders + successful_orders), 3) AS cancel_rate
FROM   (SELECT DATE_PART('hour', creation_time)::INT AS hour,
               COUNT(order_id) FILTER (WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')) AS successful_orders,
			   COUNT(order_id) FILTER (WHERE order_id IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')) AS canceled_orders
        FROM orders
        GROUP BY 1
        ORDER BY 1) t1
		
		
---------------------------------------------------------------------------------------------

