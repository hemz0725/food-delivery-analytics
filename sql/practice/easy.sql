-- Food Delivery Analytics — Easy Questions
-- 12 questions covering revenue totals, order status split, top customers, delivery times, city and restaurant rankings, agent ratings, signup trends, failed deliveries, and category revenue

--- 1. What is the total revenue generated across all orders in the dataset?

select SUM(o.order_amount)
from orders o;

--- 2. How many orders were Delivered vs Cancelled? What percentage of total orders does each status represent?

--- Clean the status values first, then compute counts from the cleaned dataset

with 
cleaned_status as
(select lower(trim(o.status)) as clnd_sts
from orders o)
select 
       count(case when clnd_sts = 'delivered' then 1 end) as dekivered_count,
	   count(case when clnd_sts = 'cancelled' then 1 end) as cancelled_count,
	   round(100.0 * count(case when clnd_sts = 'delivered' then 1 end) / count(*), 2) as delivered_pctng,
	   round(100.0 * count(case when clnd_sts = 'cancelled' then 1 end) / count(*), 2) as cancelled_pctng
from cleaned_status;

--- 3. Who are the top 5 customers by total amount spent? List their names and total spend.

--- Null values are silently removed. Make sure we inform that or use a coalesce clause with whatever data they give

select c.customer_id  
	  ,c.customer_name
	  ,sum(o.order_amount) as customer_total_spending
from customers c 
join orders o 
on c.customer_id = o.customer_id 
where LOWER(TRIM(o.status)) = 'delivered'
group by c.customer_id, c.customer_name   
order by sum(o.order_amount) desc
limit 5;

--- if a fill value is provided (e.g., ₹5,000 for the NULL amount), the query becomes,

SELECT c.customer_id, c.customer_name, 
       SUM(COALESCE(o.order_amount, 5000)) AS revised_amount
FROM customers c 
JOIN orders o ON c.customer_id = o.customer_id 
GROUP BY c.customer_id, c.customer_name
ORDER BY revised_amount DESC
LIMIT 5;

--- 4. What is the average delivery time in minutes across all delivered orders?

with 
cleaned_status_data as
(select o.delivery_time_minutes, 
 	   lower(trim(o.status))as cleaned_status
from orders o)
select 
	   round(avg(delivery_time_minutes), 2) as average_delivery_time
from cleaned_status_data 
where cleaned_status = 'delivered';

--- 5. Which city generates the most revenue? Consider only delivered orders.

with 
cleaned_status_data as
(select o.order_amount,
		lower(trim(o.status))as cleaned_status,
	    o.restaurant_id 
from orders o),
cleaned_city_names as
(select INITCAP(TRIM(r.city)) as revised_names,
	    r.restaurant_id 
from restaurants r) 
select revised_names,
	   sum(order_amount) as total_revenue
from cleaned_city_names 
join cleaned_status_data 
on cleaned_status_data.restaurant_id = cleaned_city_names.restaurant_id 
where cleaned_status = 'delivered'
group by cleaned_city_names.revised_names
order by total_revenue desc limit 1;

--- 6. What is the average delivery rating per agent? Rank them from best to worst.

select da.agent_id
	  ,da.agent_name 
	  ,round(avg(d.delivery_rating), 1) as average_rating
from delivery_agents da 
join deliveries d 
on da.agent_id = d.agent_id 
where LOWER(trim(d.delivery_status)) = 'delivered'
group by da.agent_id,da.agent_name
order by average_rating desc;

--- 7. Which restaurant has the highest total revenue from delivered orders?

with 
revenue_data as 
(select r.restaurant_id 
	  ,r.restaurant_name 
	  ,sum(o.order_amount) as total_revenue
from restaurants r 
join orders o 
on r.restaurant_id = o.restaurant_id 
where lower(TRIM(o.status)) = 'delivered' 
group by r.restaurant_id, r.restaurant_name),
ranking as
(select *,
		rank() over (order by total_revenue desc) as rnk
from revenue_data)
select *
from ranking 
where rnk = 1;

--- 8. How many orders did each restaurant receive in total? Include cancelled orders in the count.

select r.restaurant_id,
	   r.restaurant_name,
	   count(o.order_id) as no_of_orders
from restaurants r 
left join orders o
on r.restaurant_id = o.restaurant_id 
group by r.restaurant_id, r.restaurant_name
order by r.restaurant_id;

--- 9. How many customers signed up each month across the dataset? Which month had the highest signups?

WITH cleaned_dates AS (
    SELECT customer_id,
           CASE 
               -- If the 5th character is a hyphen, it is strictly YYYY-MM-DD (e.g., 2022-03-14)
               WHEN signup_date LIKE '____-%' THEN TO_DATE(signup_date, 'YYYY-MM-DD')
               -- Otherwise, it falls back to parsing the DD-Mon-YYYY format (e.g., 14-Feb-2022)
               ELSE TO_DATE(signup_date, 'DD-Mon-YYYY')
           END AS structural_signup_date
    FROM customers
),
monthly_aggregates AS (
    SELECT DATE_TRUNC('month', structural_signup_date) AS month_bucket,
           -- TRIM handles trailing spaces some engines pad to the string name
           TRIM(TO_CHAR(DATE_TRUNC('month', structural_signup_date), 'Month')) AS month_name,
           COUNT(customer_id) AS signup_count
    FROM cleaned_dates
    -- Every non-aggregated expression in SELECT must be anchored in the GROUP BY block
    GROUP BY DATE_TRUNC('month', structural_signup_date),
             TO_CHAR(DATE_TRUNC('month', structural_signup_date), 'Month')
),
ranked_timeline AS (
    SELECT month_name,
           signup_count,
           -- Generates the tie-breaking safety rank for the peak calculation
           DENSE_RANK() OVER (ORDER BY signup_count DESC) AS peak_rank
    FROM monthly_aggregates
)
-- Isolate the absolute peak signup month matching the business prompt requirement
SELECT month_name,
       signup_count
FROM ranked_timeline
WHERE peak_rank = 1;

--- 10. How many deliveries have a status of 'Failed'? Which agent was responsible?

select	da.agent_id
	   ,da.agent_name
	   ,count(
	   case when lower(trim(d.delivery_status)) = 'failed' then d.delivery_id end) as failed_deliveries_count
from delivery_agents da
left join deliveries d  
on da.agent_id = d.agent_id
group by da.agent_id, da.agent_name
ORDER BY failed_deliveries_count desc;

--- 11. What is the total revenue generated per restaurant category? Which category leads?

with category_revenue as
(select r.category,
	   sum(o.order_amount) as total_revenue
from orders o
left join restaurants r 
on o.restaurant_id = r.restaurant_id
where lower(trim(o.status)) = 'delivered' 
group by r.category),
category_ranking as 
(select *,
		rank() over(order by total_revenue desc) as rnk
from category_revenue) 
select *
from category_ranking 
where rnk = 1;

--- 12. Which delivery agents have handled the most orders? List the top 5.

with leaderboard as
(select 
		da.agent_id,
		da.agent_name,
		count(d.order_id) as no_of_orders
from deliveries d
left join delivery_agents da 
on d.agent_id = da.agent_id
group by da.agent_id, da.agent_name),
ranking as
(select *,
		dense_rank() over(order by no_of_orders desc) as rnk
from leaderboard)
select *
from ranking 
where rnk <= 5;
