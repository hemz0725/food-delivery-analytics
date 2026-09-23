-- Food Delivery Analytics — Medium Questions
-- 18 questions covering retention, month-over-month revenue, cancellation rates, rating distributions, missing data, cohort analysis, weekday vs weekend behaviour, outliers, and cross-table data quality checks

--- 13. How many customers have placed more than one order? How many ordered exactly once? What does this say about retention?

with order_counting as
(select
		c.customer_id,
		count(o.order_id) as no_of_orders
from customers c 
left join orders o 
on c.customer_id = o.customer_id 
group by c.customer_id),
orders_count as
(select *,
		case 
			when no_of_orders > 1 then '>1'
			when no_of_orders = 1 then '=1'
			else '0'
		end
			as category
from order_counting)
select 
	category,
	count(customer_id) as customer_count
from orders_count 
group by category;

--- Customers with more than one order indicate returning users, which reflects stronger customer retention. Customers with exactly one order represent one-time buyers. A higher repeat-order count generally suggests better retention and customer loyalty.

--- 14. What is the total revenue per month (Jan, Feb, Mar)? Is revenue growing or declining month over month?

with daily_revenue as 
(select to_date(o.order_date, 'yyyy-MM-dd') as dates,
	   o.order_amount 
from orders o 
where lower(trim(o.status)) = 'delivered'),
grouping as
(select date_trunc('months', dates),
	   to_char(date_trunc('months', dates), 'Mon') as months,
	   SUM(order_amount) as monthly_revenue 
from daily_revenue
group by date_trunc('months', dates),
	   to_char(date_trunc('months', dates), 'Mon'))
select months ,
	   monthly_revenue 
from grouping 

--- 15. Which restaurant category has the highest average delivery time? Only consider delivered orders.

with delivery_time as
(select 
		r.category,
		round(avg(o.delivery_time_minutes), 2) as average_delivery_time
from orders o 
left join deliveries d
on o.order_id  =  d.order_id 
left join restaurants r 
on o.restaurant_id = r.restaurant_id 
where lower(trim(d.delivery_status)) = 'delivered'
group by category),
ranking as
(select *,
		rank() over (order by average_delivery_time desc) as rnk
from delivery_time)
select *
from ranking 
where rnk = 1;

--- 16. Within each city, which delivery agent has the best average rating? Are there cities with consistently low-rated agents?

with rating as
(select da.agent_id,
	   da.agent_name,
	   da.city,
	   round(avg(d.delivery_rating), 2) as d_rating
from delivery_agents da 
left join deliveries d
on da.agent_id = d.agent_id 
and LOWER(TRIM(d.delivery_status)) = 'delivered'
group by da.city, da.agent_id,da.agent_name),
ranking as
(select *,
		rank() over(partition by city order by d_rating desc) as rnk
from rating)
select *
from ranking 
where rnk = 1;

--- Hyderabad has the lowest top-agent rating (A11 - Sudharshan V)

--- 17. Which customers have the highest cancellation rate (cancelled orders ÷ total orders)? Should any of them be flagged?

with order_counting as
(select c.customer_id,
		c.customer_name,
		round(count(o.order_id), 2) as total_no_of_orders,
		round(count(case
			when lower(trim(o.status)) = 'cancelled'  then o.order_id 
		end)
	,2) as cancelled_order_counting
from orders o
left join customers c 
on o.customer_id = c.customer_id
group by c.customer_id, c.customer_name)
select *, 
		round(cancelled_order_counting/total_no_of_orders, 2) *100 as cancellation_rate_in_percent
from order_counting 

--- to know the customers whose cancellation percentage > 75, we can filter them. And we can flag them out if we want.

with order_counting as
(select c.customer_id,
		c.customer_name,
		count(o.order_id) as total_no_of_orders,
		count(case
			when lower(trim(o.status)) = 'cancelled'  then 1 
		end
	) as cancelled_order_counting
from orders o
left join customers c 
on o.customer_id = c.customer_id
group by c.customer_id, c.customer_name),
final as
(select *, 
		round(cancelled_order_counting *100 /nullif(total_no_of_orders, 0)
		, 2) as cancellation_rate_in_percent
from order_counting)
select *
from final 
where 	total_no_of_orders >= 3 --- threshold
order by "final".cancellation_rate_in_percent desc;

--- C018, Rithika Anand has to be flagged.

--- 18. What is the average order value per city, considering only delivered orders? Which city has customers who spend the most per order?

with city_revemue as
(select LOWER(trim(c.city)) as cleaned_city,
		round(avg(o.order_amount), 2) as city_avg_revenue
from customers c   
inner join orders o 
on c.customer_id  = o.customer_id  
where lower(trim(o.status)) = 'delivered'
group by cleaned_city),
ranking as
(select 	*,
		rank() over (order by city_avg_revenue desc) as rnk
from city_revemue)
select  *
from ranking 
where rnk = 1;

--- 19. How many deliveries received each rating (1 through 5)? What percentage of deliveries have a rating of 3 or below?

with rating as
(select d.delivery_rating,
	   count(d.delivery_id) as orders_per_rating,
	   sum(count(d.delivery_id)) over() as total_no_of_orders
from deliveries d
group by d.delivery_rating)
select 	coalesce(cast(delivery_rating as varchar), 'unrated') as rating_bucket,
		orders_per_rating,
		round(orders_per_rating * 100.0 / total_no_of_orders, 2) as pct_of_orders_per_rating,
		round((sum(case when delivery_rating <= 3 then orders_per_rating
		end) over() *100)/ total_no_of_orders , 2) as pct_of_deliveries
from rating
order by delivery_rating asc nulls last;

--- 20. How many delivered orders have no rating recorded? and Which agents are most affected by missing ratings — and should missing ratings be treated as neutral or excluded from performance scoring?

with rating as
(select da.agent_id,
		da.agent_name,
		d.delivery_rating
from delivery_agents da 
join deliveries d
on da.agent_id = d.agent_id
where lower(trim(d.delivery_status)) = 'delivered'),
unrated_orders_data as
(select  agent_id, agent_name,
		 round(avg(delivery_rating), 2) as average_rating,
		 count(
		case
			when delivery_rating is null then 1
		end) as unrated_orders,
		round(count(case
			when delivery_rating is null then 1
		end) * 100.0 / count(*), 2) as percentage_of_unrated_deliveries
from rating 
group by agent_id, agent_name)
select *
from unrated_orders_data  
where unrated_orders > 0;

--- 21. For each customer who has ordered more than once, which restaurant did they order from the most? 
--- What does this reveal about loyalty to specific restaurants?

with customer_order_count as
(select c.customer_id,
	   c.customer_name,
	   o.restaurant_id,
	   r.restaurant_name,
	   count(o.order_id) as customer_order_count_per_r,
	   sum(count(o.order_id)) over(partition by c.customer_id) total_no_of_orders_per_c
from customers c 
left join orders o  
on c.customer_id = o.customer_id 
left join restaurants r 
on  o.restaurant_id = r.restaurant_id 
group by c.customer_id,
	   c.customer_name,
	   o.restaurant_id,
	   r.restaurant_name),
customer_orders as	   
(select *
from customer_order_count
where total_no_of_orders_per_c > 1),
ranking as 
(select customer_id, customer_name, restaurant_id, restaurant_name, customer_order_count_per_r,
		dense_rank() over(PARTITION BY customer_id order by customer_order_count_per_r desc) as rnk
from customer_orders)
select *
from ranking
where rnk = 1;

--- Most repeat customers do not appear strongly tied to a single restaurant, suggesting relatively low restaurant-level loyalty and more exploratory ordering behavior.

--- 22. Compare total revenue on weekdays vs weekends. Do customers order more frequently on weekends, or do they spend more per order?

WITH cleaned_orders AS (
    SELECT
        order_id,
        order_amount,
        TO_DATE(order_date, 'YYYY-MM-DD') AS order_dt
    FROM orders
    WHERE LOWER(TRIM(status)) = 'delivered')
SELECT
    CASE
        WHEN EXTRACT(ISODOW FROM order_dt) IN (6, 7) THEN 'weekend'
        ELSE 'weekday'
    END AS day_type,
    COUNT(*) AS total_orders,
    SUM(order_amount) AS total_revenue,
    ROUND(AVG(order_amount), 2) AS avg_order_value
FROM cleaned_orders
GROUP BY day_type;

--- 23. Group customers by the year they signed up (2021, 2022, 2023). How much of the total order volume and revenue does each cohort account for? Which cohort is most active?

with cleaned_dates as (
select	c.customer_id, 
		case 
			when signup_date ~ '^[0-9]{4}' then to_date(signup_date, 'yyyy-MM-dd')
			when signup_date ~ '[0-9]{4}$' then to_date(signup_date, 'dd-Mon-yyyy')
		end
		as cleaned_dates,
		o.order_id ,
		o.order_amount
from customers c 
left join orders o
on c.customer_id = o.customer_id 
and LOWER(trim(o.status)) = 'delivered'
),
years as (
select	*, date_trunc('year', cleaned_dates) as years
from cleaned_dates
),
year_name_setting as
(select *, extract(year from years) as year_name, count(order_id)  over () as no_of_orders, sum(order_amount) over() as total_revenue
from years)
select 	year_name,
		sum(order_amount) as total_revenue_per_cohort,
		round(avg(order_amount), 2) as avg_order_value,
		count(order_id) as order_count_per_cohort,
		round(count(order_id) * 100.0 / MAX(no_of_orders), 2) as order_volume,
		round(SUM(order_amount) * 100.0 / MAX(total_revenue) , 2) as rev_percentage
from year_name_setting
group by year_name;

--- with the order volume and rev_percentage, cohort 2022 stays at the top. But for a clearer picture, we'd also have to measure retention rate to check the customers' behaviour overtime.

--- 24. List the top 10 orders with the highest delivery time. Are these clustered around specific restaurants, agents, or cities — or are they random outliers?

WITH cleaned_data AS (
    SELECT
        o.order_id,
        d.delivery_id,
        d.agent_id,
        r.restaurant_id,
        r.restaurant_name,
        LOWER(TRIM(r.city)) AS cleaned_cities,
        o.delivery_time_minutes
    FROM deliveries d
    JOIN orders o
        ON d.order_id = o.order_id
    JOIN restaurants r
        ON o.restaurant_id = r.restaurant_id
    WHERE LOWER(TRIM(o.status)) = 'delivered'
      AND LOWER(TRIM(d.delivery_status)) = 'delivered'
),
ranking AS (
    SELECT
        *,
        RANK() OVER (ORDER BY delivery_time_minutes DESC) AS rnk
    FROM cleaned_data
),
needed_data AS (
    SELECT *
    FROM ranking
    WHERE rnk <= 10
)
SELECT
    order_id,
    restaurant_id,
    restaurant_name,
    agent_id,
    cleaned_cities,
    delivery_time_minutes,
    COUNT(*) OVER(PARTITION BY restaurant_id) AS top10_count_by_restaurant,
    COUNT(*) OVER(PARTITION BY agent_id) AS top10_count_by_agent,
    COUNT(*) OVER(PARTITION BY cleaned_cities) AS top10_count_by_city
FROM needed_data
ORDER BY delivery_time_minutes DESC;

--- with this data, r13 has the most no. of orders in the top 10 orders that have the highest_delivery_time. And agent 05 has repeatedly delivered late. And these are just the top 10 not the only ones that has delivery time more than 60 mins. 

--- 25. Is there a pattern between how many deliveries an agent handles and their average rating? Do busier agents tend to perform worse?

select 	da.agent_id,
		count(d.order_id) as no_of_orders,
 		round(avg(case
			when lower(trim(delivery_status)) = 'failed' then null
			else d.delivery_rating 
		end), 2) as avg_cleaned_rating
from delivery_agents da 
join deliveries d 
on da.agent_id = d.agent_id
group by da.agent_id
order by avg_cleaned_rating desc nulls last

--- there's no pattern between how many deliveries an agent handles and their average rating. No, busier agents do not tend to perform worse. To understand the root cause of bad rating, we should find customer satisfaction score and avg_delivery_time in different regions, in different restaurants and in different food categories.

--- 26. What percentage of total revenue comes from orders above ₹1000? How many such orders exist and from which restaurants do they mostly come?

with rev as
(select o.order_id,
		o.order_amount,
		sum(o.order_amount) over() as total_revenue,
		o.restaurant_id 
from orders o
where lower(trim(status)) = 'delivered'),
filtered_rev as 
(select order_id,
		order_amount,
		restaurant_id ,
		count(order_id) over() as total_count,
		sum(order_amount) over() as revenue_from_orders_more_than_1000,
		total_revenue
from rev  
where order_amount > 1000)
select 	restaurant_id,
		count(order_id) as orders_per_restaurant,
		total_count,
		round(max(revenue_from_orders_more_than_1000) * 100.0 / max(total_revenue), 2) as revenue_pct
from filtered_rev
group by restaurant_id, total_count
order by orders_per_restaurant desc

--- There are 15 orders above ₹1000 in total, and 4 of them came from R12 alone. But this doesn't mean that that's the only restaurant that performs well. A minimum order count threshold (of 10) for the orders that cost more than 1000 will give us a better understanding. However, high-value order concentration alone should not be used as a measure of restaurant performance. And to find the best restaurant, we have to consider the customer satisfaction score, retention rate. repeat purchase rate, CLTV, revenue for each restaurant.

--- 27. Which restaurants have zero cancelled orders in the dataset? Is this a data quality issue, a business strength, or just low order volume?

with cancelled_orders_count as (
select  o.restaurant_id,
		count(
		case 
			when lower(trim(o.status)) = 'cancelled' then o.order_id 
		end
		) as cancelled_orders
from orders o
group by o.restaurant_id
)
select *
from cancelled_orders_count 
where cancelled_orders = 0
order by restaurant_id 

--- This analysis only identifies restaurants with zero cancelled orders. Based on this result alone, we cannot determine whether this reflects strong operational performance, low order volume, or another factor. Additional metrics such as total order volume and cancellation rate are required before drawing a conclusion. There is no evidence from the current dataset that this is a data quality issue.

--- 28. For each city, which restaurant category do customers order from the most? Do Pondicherry customers behave differently from Chennai customers?

with category_filtering as (
select   case 
	when LOWER(trim(c.city)) = 'pondy' then 'pondicherry'
	else LOWER(trim(c.city))
end as cleaned_cities,
		r.category,
		count(o.order_id) as category_order_count_per_city
from restaurants r 
join orders o 
on r.restaurant_id  = o.restaurant_id 
join customers c 
on o.customer_id = c.customer_id 
group by cleaned_cities, r.category
),
ranking as (
select *, rank() over(partition by cleaned_cities order by category_order_count_per_city desc) as rnk
from category_filtering
)
select *
from ranking
where rnk = 1
and cleaned_cities in ('chennai', 'pondicherry')

---  Chennai customers most frequently order Pizza, while Pondicherry customers most frequently order Cafe items. This suggests customer preferences differ between the two cities. As a result, the company may benefit from city-specific marketing campaigns, restaurant acquisition strategies, and promotional offers rather than using a single strategy across all locations. However, additional metrics such as revenue contribution and customer retention by category would be required before making broader operational decisions.

--- 29. Are there any orders marked as 'Delivered' in the orders table that have no corresponding record in the deliveries table? What might cause this in a real system?

with cleaned_data as (
select 	o.order_id,
		lower(trim(o.status)) as cleaned_status,
		d.delivery_id
from orders o 
left join deliveries d 
on o.order_id = d.order_id 
and lower(trim(o.status)) = 'delivered'
)
select *
from cleaned_data 
where cleaned_status = 'delivered' and delivery_id is null 

--- There is no order marked as 'Delivered' in the orders table that has no corresponding record in the deliveries table. And this means the data is clean in this case but mismatches could occur due to data pipeline failures, missing delivery records, synchronization issues between systems, or incorrect status updates.

--- 30. How much total order revenue has each delivery agent handled? Rank them. Should agent bonuses be based on this number?

with revenue as (
select 	d.agent_id, 
		sum(o.order_amount) as agent_revenue
from orders o
join deliveries d 
on o.order_id = d.order_id 
where lower(trim(o.status)) = 'delivered'
group by d.agent_id
order by agent_id 
)
select *,
		rank () over (order by agent_revenue desc) as rnk
from revenue
