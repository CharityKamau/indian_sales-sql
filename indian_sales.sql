DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
	Customer_ID VARCHAR(20),
	Customer_Name VARCHAR(100),
	Gender VARCHAR(10),
	Age INT,
	Age_Group VARCHAR(10),
	Date_of_Birth DATE,
	Email VARCHAR(100),
	Phone VARCHAR(100),
	City VARCHAR(100),
	State VARCHAR(100),
	Pincode INT,
	Registration_Date DATE,
	Customer_Tier VARCHAR(20),
	Total_Orders INT,
	Total_Spent NUMERIC
	
	);

DROP TABLE IF EXISTS products;
CREATE TABLE products (
	Product_ID VARCHAR(20),
	Product_Name VARCHAR(50),
	Category VARCHAR(100),
	Brand VARCHAR(25),
	Original_Price FLOAT,
	Discount_Percent INT,
	Discount_Amount FLOAT,
	Selling_Price NUMERIC,
	Stock_Quantity INT,
	Weight_kg FLOAT,
	Avg_Rating FLOAT,
	Total_Reviews INT
	
);	

DROP TABLE IF EXISTS sales;
CREATE TABLE sales(
	Order_ID VARCHAR(20),
	Customer_ID VARCHAR(20),
	Product_ID VARCHAR(20),
	Order_Date DATE,
	Order_Time TIME,
	Delivery_Date DATE,
	Quantity INT,
	Unit_Price NUMERIC,
	Order_Value NUMERIC,
	Shipping_Cost NUMERIC,
	Coupon_Code VARCHAR(10),
	Coupon_Discount NUMERIC,
	Total_Amount FLOAT,
	Payment_Mode VARCHAR(20),
	Order_Status VARCHAR(20),
	Rating DECIMAL,
	Review_Text VARCHAR(100),
	City VARCHAR(100),
	State  VARCHAR(100),
	Customer_Age INT,
	Customer_Age_Group VARCHAR(10)

	);

---SALES & REVENUE
--1.Total revenue
SELECT 
 SUM(total_amount) AS revenue
FROM sales;

--2.Average order value
SELECT
  AVG(total_amount) AS average_order
FROM sales;

--3.Month with the highest revenue
SELECT
	EXTRACT(YEAR FROM order_date) AS year,
	EXTRACT(MONTH FROM order_date) AS month,
	SUM(total_amount) AS revenue
FROM sales
GROUP BY year,month
ORDER BY revenue DESC
LIMIT 1;

--4.Monthly/quarterly sales trend
SELECT
	DATE_TRUNC('quarter', order_date) AS quarter,
	SUM(total_amount) AS total_sales
FROM sales
GROUP BY DATE_TRUNC('quarter', order_date)
ORDER BY quarter;

--5.percentage of total revenue comes from each category
SELECT 
	p.category,
	SUM(s.total_amount) AS category_sales,
	ROUND(
		SUM(s.total_amount) * 100.0 /
		SUM(SUM(s.total_amount)) OVER(),
		2
		) AS revenue_percentage
FROM sales s
JOIN products p
	ON s.Product_ID = p.Product_ID
GROUP BY p.category
ORDER BY  category_sales DESC;

--6.Product with the highest sales
SELECT p.product_name,
	SUM(s.total_amount) AS total_sales
FROM sales s
JOIN products p
	ON s.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_sales DESC
LIMIT 1;


---PRODUCT PERFORMANCE
--7.Category with the highest number of orders
SELECT p.category,
	COUNT(DISTINCT order_id) AS total_orders
FROM sales s
JOIN products p
	ON s.product_id = p.product_id
GROUP BY p.category
ORDER BY total_orders DESC
LIMIT 1;

--8.Top 10 best-selling products
SELECT p.product_name,
	SUM(s.total_amount) AS total_sales
FROM sales s
JOIN products p
	ON s.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_sales DESC
LIMIT 10;

--9.Products with high revenue but relatively few orders
SELECT
    p.product_id,
    p.product_name,
    p.category,
    COUNT(s.order_id) AS total_orders,
    SUM(s.total_amount) AS total_revenue
FROM sales s
JOIN products p
    ON s.product_id = p.product_id
GROUP BY
    p.product_id,
    p.product_name,
    p.category
HAVING
    SUM(s.total_amount) > (
        SELECT AVG(total_revenue)
        FROM (
            SELECT
                product_id,
                SUM(total_amount) AS total_revenue
            FROM sales
            GROUP BY product_id
        ) AS product_sales
    )
    AND COUNT(s.order_id) < (
        SELECT AVG(total_orders)
        FROM (
            SELECT
                product_id,
                COUNT(order_id) AS total_orders
            FROM sales
            GROUP BY product_id
        ) AS product_orders
    )
ORDER BY total_revenue DESC;

--Rank products according to their total sales
SELECT
	p.product_id,
	p.product_name,
	p.category,
	SUM(s.total_amount) AS total_sales,
	RANK() OVER (
		ORDER BY SUM(s.total_amount) DESC
	) AS sales_rank
FROM sales s
JOIN products p
	ON s.product_id = p.product_id
GROUP BY
	p.product_id,
	p.product_name,
	p.category
ORDER BY sales_rank;

--top product per category
WITH product_sales AS (
	SELECT
		p.category,
		p.product_id,
		p.product_name,
		SUM(s.total_amount) AS total_sales
	FROM sales s
	JOIN products p
		ON s.product_id = p.product_id
	GROUP BY
		p.category,
		p.product_id,
		p.product_name
),
ranked_products AS (
	SELECT
		category,
		product_id,
		product_name,
		total_sales,
		RANK() OVER (
			PARTITION BY category
            ORDER BY total_sales DESC
        ) AS product_rank
    FROM product_sales
)
SELECT
    category,
    product_id,
    product_name,
    total_sales
FROM ranked_products
WHERE product_rank = 1
ORDER BY category;

---Cumulative sales over time
SELECT
	order_date,
	SUM(total_amount) AS daily_sales,
	SUM(SUM(total_amount)) OVER (
		ORDER BY order_date
		) AS cumulative_sales
FROM sales
GROUP BY order_date
ORDER BY order_date;

--monthly sales
SELECT
    EXTRACT(MONTH FROM order_date) AS month,
    EXTRACT(YEAR FROM order_date) AS year,
    SUM(total_amount) AS total_sales
FROM sales
GROUP BY year, month
ORDER BY total_sales DESC;

--Customer ranking
SELECT
	customer_id,
	SUM(total_amount) AS total_sales,
	RANK () OVER (
		ORDER BY SUM(total_amount) DESC
		) AS customer_rank
FROM sales
GROUP BY customer_id
ORDER BY customer_rank

--Month-over-Month sales
WITH monthly_sales AS (
	SELECT
		EXTRACT(MONTH FROM order_date) AS month,
		SUM(total_amount) AS total_sales
	FROM sales
	GROUP BY EXTRACT(MONTH FROM order_date) AS month
	)
SELECT
	month,
	total_sales,
	LAG(total_sales) OVER (
		  ORDER BY month
    ) AS previous_month_sales,
    ROUND(
        (total_sales - LAG(total_sales) OVER (ORDER BY month))
        / NULLIF(LAG(total_sales) OVER (ORDER BY month), 0) * 100,
        2
    ) AS mom_growth_percent
FROM monthly_sales
ORDER BY month;
		
---Customer segmentation
SELECT 
	customer_id,
	COUNT(DISTINCT order_id) AS total_orders,
	SUM(total_amount) AS total_spending,
	
	CASE 
		WHEN SUM(total_amount) >= 1000000 THEN 'High Value Customer'
		WHEN SUM(total_amount) >= 50000 THEN 'Medium value Customer'
		WHEN SUM(total_amount) < 50000 THEN 'Low value Customer'
		ELSE 'Unknown'
	END AS customer_segment
	
FROM sales
GROUP BY customer_id
ORDER BY total_spending DESC;

---Best performing state
SELECT
	state,
	SUM(total_amount) AS total_sales
FROM sales
GROUP BY state
ORDER BY total_sales DESC;

--_Category contribution
SELECT
 category,
 SUM(total_amount) AS category_revenue,
 ROUND(
 	SUM(total_amount) * 100.0 /
	SUM(SUM(total_amount)) OVER () ::numeric,
		2
		) AS percentage_contribution
FROM sales s
JOIN products p
	ON s.product_id = p.product_id
GROUP BY category
ORDER BY percentage_contribution DESC;
	
 

				




