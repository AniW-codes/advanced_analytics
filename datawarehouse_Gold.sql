select * from [gold.fact_sales]

---------Sales/Change over time----------


select 
		Year(order_date) as yr,
		MONTH(order_date) as month,
		SUM(sales_amount) as totalsales,
		COUNT(DISTINCT customer_key) as distinct_customers,
		SUM(quantity) as total_qty
from [gold.fact_sales]
where order_date is not null
group by Year(order_date), MONTH(order_date)
order by Year(order_date), MONTH(order_date)

----------

select 
		DATETRUNC(month, order_date),
		SUM(sales_amount),
		SUM(quantity) as total_quantity,
		COUNT(DISTINCT customer_key) as distinct_customers

from [gold.fact_sales]
where order_date is not null
group by DATETRUNC(month, order_date)
order by DATETRUNC(month, order_date)

------------

select 
		DATETRUNC(YEAR, order_date) as dates,
		SUM(sales_amount) as total_amt,
		SUM(quantity) as total_quantity,
		COUNT(DISTINCT customer_key) as distinct_customers
from [gold.fact_sales]
where order_date is not null
group by DATETRUNC(YEAR, order_date)
order by DATETRUNC(YEAR, order_date)


------------
select 
		FORMAT(order_date, 'yyyy-MMM') as dates,
		SUM(sales_amount) as tot_amt,
		SUM(quantity) as total_quantity,
		COUNT(DISTINCT customer_key) as distinct_customers
from [gold.fact_sales]
where order_date is not null
group by FORMAT(order_date, 'yyyy-MMM')
order by FORMAT(order_date, 'yyyy-MMM')


---------Cumulative Analysis----------

--Calculate total sales for each month and running total of sales over time

select * from [gold.fact_sales]


select 
		yearly_date,
		total_amt,
		SUM(total_amt) OVER(Order by yearly_date) as running_sales
from
					(select 
						DATETRUNC(YEAR, order_date) as yearly_date,
						SUM(sales_amount) as total_amt
					from [gold.fact_sales]
					where order_date is not null
					group by DATETRUNC(YEAR, order_date)
					) as t1



------------

select 
		yearly,
		total_amt,
		SUM(total_amt) OVER(Order by yearly) as running_sales,
		AVG(avg_price) OVER(Order by yearly) as running_avg_price
from
						(select 
							DATETRUNC(YEAR, order_date) as yearly,
							SUM(sales_amount) as total_amt,
							AVG(price) as avg_price
						from [gold.fact_sales]
						where order_date is not null
						group by DATETRUNC(YEAR, order_date)
						) as t1



-------------Performance Analysis--------------

--Analyse the yearly performance of products by comparing each product's sales to both [Avg sales performance and previous years sales perf]

select * from [gold.dim_products]
select * from [gold.fact_sales]

---

With Yearly_Product_Sales as
			(select 
					YEAR(order_date) as year,
					product_name,
					SUM(sales_amount) as total_sales
			from [gold.dim_products]
			left join [gold.fact_sales]
				on [gold.dim_products].product_key = [gold.fact_sales].product_key
			where order_date is not null
			group by YEAR(order_date), product_name
			)

Select 
		year,
		product_name,
		total_sales,
		AVG(total_sales) Over(Partition by product_name) as avg_sales,
		total_sales - AVG(total_sales) Over(Partition by product_name) as avg_difference,
		CASE	
			When total_sales - AVG(total_sales) Over(Partition by product_name) > 0 then 'above avg'
			When total_sales - AVG(total_sales) Over(Partition by product_name) < 0 then 'below avg'
			else 'average'
		END as status_of_average,
		LAG(total_sales) Over(Partition by product_name order by year) as previous_year_sale,
		total_sales - LAG(total_sales) Over(Partition by product_name order by year) as difference_comparison_to_previous_year,
		CASE	
			When total_sales - LAG(total_sales) Over(Partition by product_name order by year) > 0 then 'Increasing Sale'
			When total_sales - LAG(total_sales) Over(Partition by product_name order by year) < 0 then 'Decreasing Sale'
			else 'No change'
		END as status_of_sale
from Yearly_Product_Sales


-------------Part to Whole Analysis--------------

--Which category contributes the most to the overall sales

With CTE_Category_Sales as
		(select 
			category,
			SUM(sales_amount) as sales_amount
		from [gold.dim_products]
		left join [gold.fact_sales]
			on [gold.dim_products].product_key = [gold.fact_sales].product_key
		where order_date is not null
		group by category)

Select 
	category,
	sales_amount,
	SUM(sales_amount) Over() as total_sales,
	CONCAT(ROUND((CAST(sales_amount as float)/SUM(sales_amount) Over()) * 100,2),'%')  as percentage_contribution 
from CTE_Category_Sales



-------------Data Segmentation--------------

--Segment product into cost range and count how many products fall into each range.

select * from [gold.dim_products]

---

With CTE_Range as 
			(Select	product_key,
					product_name,
					cost,
					CASE	
						When cost < 100 then 'Less than 100'
						When cost between 100 and 500 then '100-500'
						When cost between 500 and 1000 then '500-1000'
						Else 'Above 1000'
					END as Range
			from [gold.dim_products])

Select Range,
		Count(product_key) as total_products
from CTE_Range
group by Range
Order by 2 desc

--Group customers into 3 segments based on their spending behaviour:
--1. VIP: Customers with atleast 12 months of history and spent >5000.
--2. Regular: Customers with atleast 12 months of history and spent 5000 or less.
--3. New: Customers with less than 12 months of history.
--And find total number of customers in each segment.

With CTE_Status as (
select 
		[gold.fact_sales].customer_key,
		MIN(order_date) as last_order,
		MAX(order_date) as latest_order,
		DATEDIFF(Month,  MIN(order_date), MAX(order_date)) as date_difference,
		CASE
			When DATEDIFF(Month,  MIN(order_date), MAX(order_date)) >= 12 and SUM(sales_amount) > 5000 then 'VIP'
			When DATEDIFF(Month,  MIN(order_date), MAX(order_date)) >= 12 and SUM(sales_amount) <= 5000 then 'Regular'
			Else 'New'
		END as customer_status,
		SUM(sales_amount) as sales_amount
from [gold.fact_sales]
left join [gold.dim_customers]
	on [gold.fact_sales].customer_key = [gold.dim_customers].customer_key
where order_date is not null
group by [gold.fact_sales].customer_key
--order by SUM(sales_amount) desc
)

Select customer_status,
		Count(customer_status)
from CTE_Status
group by customer_status




-------------Customer Reports--------------
/*
===============================================================================
Customer Report
===============================================================================
Purpose:
    - This report consolidates key customer metrics and behaviors

Highlights:
    1. Gathers essential fields such as names, ages, and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and age groups.
    3. Aggregates customer-level metrics:
	   - total orders
	   - total sales
	   - total quantity purchased
	   - total products
	   - lifespan (in months)
    4. Calculates valuable KPIs:
	    - recency (months since last order)
		- average order value
		- average monthly spend
===============================================================================
*/

-- =============================================================================
-- Create Report: gold.report_customers
-- =============================================================================
IF OBJECT_ID('gold.report_customers', 'V') IS NOT NULL
    DROP VIEW gold.report_customers;
GO

CREATE VIEW 
	gold.report_customers 
AS

WITH base_query AS( --CTE1
/*---------------------------------------------------------------------------
1) Base Query: Retrieves core columns from tables
---------------------------------------------------------------------------*/
SELECT
order_number,
product_key,
order_date,
sales_amount,
quantity,
c.customer_key,
customer_number,
CONCAT(first_name, ' ', last_name) AS customer_name,
DATEDIFF(year, birthdate, GETDATE()) age
FROM [gold.fact_sales] f
LEFT JOIN [gold.dim_customers] c
ON c.customer_key = f.customer_key
WHERE order_date IS NOT NULL)

, 
customer_aggregation AS ( --CTE2
/*---------------------------------------------------------------------------
2) Customer Aggregations: Summarizes key metrics at the customer level
---------------------------------------------------------------------------*/
SELECT 
	customer_key,
	customer_number,
	customer_name,
	age,
	COUNT(DISTINCT order_number) AS total_orders,
	SUM(sales_amount) AS total_sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT product_key) AS total_products,
	DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan,
	MAX(order_date) as last_order_date
FROM base_query
GROUP BY 
	customer_key,
	customer_number,
	customer_name,
	age
)
SELECT
customer_key,
customer_number,
customer_name,
age,
CASE 
	 WHEN age < 20 THEN 'Under 20'
	 WHEN age between 20 and 29 THEN '20-29'
	 WHEN age between 30 and 39 THEN '30-39'
	 WHEN age between 40 and 49 THEN '40-49'
	 ELSE '50 and above'
END AS age_group,
CASE 
    WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
    WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
    ELSE 'New'
END AS customer_segment,
last_order_date,
DATEDIFF(month, last_order_date, GETDATE()) AS recency,
total_orders,
total_sales,
total_quantity,
total_products
lifespan,
-- Compuate average order value (AVO)
CASE WHEN total_sales = 0 THEN 0
	 ELSE total_sales / total_orders
END AS avg_order_value,
-- Compuate average monthly spend
CASE WHEN lifespan = 0 THEN total_sales
     ELSE total_sales / lifespan
END AS avg_monthly_spend
FROM customer_aggregation


/*
===============================================================================
Product Report
===============================================================================
Purpose:
    - This report consolidates key product metrics and behaviors.

Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    3. Aggregates product-level metrics:
       - total orders
       - total sales
       - total quantity sold
       - total customers (unique)
       - lifespan (in months)
    4. Calculates valuable KPIs:
       - recency (months since last sale)
       - average order revenue (AOR)
       - average monthly revenue
===============================================================================
*/
-- =============================================================================
-- Create Report: gold.report_products
-- =============================================================================
IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
    DROP VIEW gold.report_products;
GO

CREATE VIEW 
gold.report_products AS



WITH base_query AS ( --CTE1
/*---------------------------------------------------------------------------
1) Base Query: Retrieves core columns from fact_sales and dim_products
---------------------------------------------------------------------------*/
    SELECT
	    order_number,
        order_date,
		customer_key,
        sales_amount,
        quantity,
        p.product_key,
        product_name,
        category,
        subcategory,
        cost
    FROM [gold.fact_sales] f
    LEFT JOIN [gold.dim_products] p
        ON f.product_key = p.product_key
    WHERE order_date IS NOT NULL  -- only consider valid sales dates
)
,
product_aggregations AS (--CTE2
/*---------------------------------------------------------------------------
2) Product Aggregations: Summarizes key metrics at the product level
---------------------------------------------------------------------------*/
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
    MAX(order_date) AS last_sale_date,
    COUNT(DISTINCT order_number) AS total_orders,
	COUNT(DISTINCT customer_key) AS total_customers,
    SUM(sales_amount) AS total_sales,
    SUM(quantity) AS total_quantity,
	ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)),1) AS avg_selling_price
FROM base_query
GROUP BY
    product_key,
    product_name,
    category,
    subcategory,
    cost
)

/*---------------------------------------------------------------------------
  3) Final Query: Combines all product results into one output
---------------------------------------------------------------------------*/
SELECT 
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	last_sale_date,
	DATEDIFF(MONTH, last_sale_date, GETDATE()) AS recency_in_months,
	CASE
		WHEN total_sales > 50000 THEN 'High-Performer'
		WHEN total_sales >= 10000 THEN 'Mid-Range'
		ELSE 'Low-Performer'
	END AS product_segment,
	lifespan,
	total_orders,
	total_sales,
	total_quantity,
	total_customers,
	avg_selling_price,
	-- Average Order Revenue (AOR)
	CASE 
		WHEN total_orders = 0 THEN 0
		ELSE total_sales / total_orders
	END AS avg_order_revenue,
	-- Average Monthly Revenue
	CASE
		WHEN lifespan = 0 THEN total_sales
		ELSE total_sales / lifespan
	END AS avg_monthly_revenue

FROM product_aggregations 