/*
Business Analysis on a delivery service company
SQL type: PostgreSQL
*/


---------------------------------------------------------------------------------------------
--creating and importing  data(CSVs) into pgAdmin4

SET datestyle = ISO, DMY;

--courier_actions table
CREATE TABLE courier_actions (
	courier_id INT,
	order_id INT,
	action VARCHAR(50),
	time TIMESTAMP WITHOUT TIME ZONE
	);

COPY courier_actions FROM 'D:\project\project4\courier_actions.csv' DELIMITER ',' CSV HEADER;


--couriers table
CREATE TABLE couriers (
	courier_id INT PRIMARY KEY,
	birth_date DATE,
	sex VARCHAR(10)
	);

COPY couriers FROM 'D:\project\project4\couriers.csv' DELIMITER ',' CSV HEADER;


--orders table
CREATE TABLE orders (
	order_id INT PRIMARY KEY,
	creation_time TIMESTAMP WITHOUT TIME ZONE,
	product_ids INTEGER[]
	);

COPY orders FROM 'D:\project\project4\orders.csv' DELIMITER ',' CSV HEADER;


--products table
CREATE TABLE products (
	product_id INT,
	name VARCHAR(100),
	price INT
	);

COPY products FROM 'D:\project\project4\products.csv' DELIMITER ',' CSV HEADER;


--user_actions table
CREATE TABLE user_actions (
	user_id INT,
	order_id INT,
	action VARCHAR(30),
	time TIMESTAMP WITHOUT TIME ZONE
	);

COPY user_actions FROM 'D:\project\project4\user_actions.csv' DELIMITER ',' CSV HEADER;


--users table
CREATE TABLE users (
	user_id INT PRIMARY KEY,
	birth_date DATE,
	sex VARCHAR(10)
	);

COPY users FROM 'D:\project\project4\users.csv' DELIMITER ',' CSV HEADER;
