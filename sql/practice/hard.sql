-- Food Delivery Analytics — Hard Questions
-- 20 questions covering churn, revenue concentration, data cleaning, CLV, rating variance, spike detection, repeat-order gaps, join inflation, customer segmentation, NULL handling, growth rates, agent leaderboards, and an executive summary

--- 31. Define a churned customer as someone who placed at least one order in January but placed zero orders in March. How many customers churned by this definition? Is this definition fair?

with jan_customers as (
select 	c.customer_id,
		c.customer_name
from customers c
left join orders o 
on c.customer_id = o.customer_id 
where to_date(o.order_date, 'yyyy-MM-dd') is not null
and lower(trim(o.status)) = 'delivered'
and to_date(o.order_date, 'yyyy-MM-dd') >= '2024-01-01'
and to_date(o.order_date, 'yyyy-MM-dd') < '2024-02-01'
),
mar_customers as (
select 	c.customer_id,
		c.customer_name
from customers c
left join orders o 
on c.customer_id = o.customer_id
where to_date(o.order_date, 'yyyy-MM-dd') is not null
and lower(trim(o.status)) = 'delivered'
and to_date(o.order_date, 'yyyy-MM-dd') >= '2024-03-01'
and to_date(o.order_date, 'yyyy-MM-dd') < '2024-04-01'
),
retention_status as (
select 	 jan_customers.customer_id,
		 jan_customers.customer_name,
		case when mar_customers.customer_id is not null then 'retained_customer'
		else 'churned_customer'
		end as retention_status
from jan_customers 
left join mar_customers 
on jan_customers.customer_id = mar_customers.customer_id 
group by jan_customers.customer_id, mar_customers.customer_id,
		 jan_customers.customer_name
)
select 	*,
		count(retention_status) over() as no_of_churned_customers_whoorderedinjanbutnotinmar
from retention_status 
where retention_status = 'churned_customer'

--- We identified 9 customers who placed a delivered order in January but did not place a delivered order in March.
--- However, this should not be treated as the true churn rate because the definition is based on only two observation months. 
---	Customers may naturally skip a month and return later.
--- A cohort analysis across consecutive months would provide a more accurate view of customer retention and repeat purchase behavior. 
--- Including February and tracking customers over multiple months would help distinguish temporary inactivity from actual churn.

--- 32. What percentage of total revenue comes from the top 3 restaurants? If those restaurants went offline, what would be the revenue impact? How dependent is the business on a small number of partners?

with restaurant_gmv as (
    select
        r.restaurant_id,
        r.restaurant_name,
        sum(o.order_amount) as restaurant_gmv
    from restaurants r
    left join orders o
        on r.restaurant_id = o.restaurant_id
       and lower(trim(o.status)) = 'delivered'
    group by
        r.restaurant_id,
        r.restaurant_name
),
ranking as (
    select *,
           round(
               restaurant_gmv * 100.0 /
               sum(restaurant_gmv) over (),
               2
           ) as rev_perc,
           dense_rank() over(order by restaurant_gmv desc) as rnk
    from restaurant_gmv
)
select *
from ranking
where rnk <= 3;

--- 33. The city field has inconsistent values like 'chennai', 'CHENNAI', and 'Pondy'. 
--- If you group by city without cleaning this data, how much does the revenue figure for Chennai get undercounted? Quantify the error.

WITH poor_data_entry AS (
    SELECT
        city,
        SUM(o.order_amount) AS revenue
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    GROUP BY city
),
correct_data_entry AS (
    SELECT
        LOWER(TRIM(city)) AS city,
        SUM(o.order_amount) AS revenue
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    GROUP BY LOWER(TRIM(city))
)
SELECT
    c.revenue AS cleaned_revenue,
    p.revenue AS naive_revenue,
    c.revenue - p.revenue AS undercount
FROM correct_data_entry c
JOIN poor_data_entry p
    ON p.city = 'Chennai'      -- use the canonical value in your dataset
WHERE c.city = 'chennai';

--- 34. Calculate a simple Customer Lifetime Value (CLV) as: average order value × number of delivered orders per customer.
--- Who are the top 10 customers by CLV? How different is this list from the top spenders list in Q3?

with aov_and_deliverycount as (
select  o.customer_id,
		sum(o.order_amount) / count(o.order_id)  as aov,
		count(o.order_id) as deli_count
from orders o 
left join customers c 
on o.customer_id = c.customer_id
where lower(trim(o.status)) = 'delivered' 
group by o.customer_id 
),
CLV_calculation as (
select *,
		aov * deli_count as CLV
from aov_and_deliverycount 
),
ranking as (
select *,
		dense_rank() over(order by clv desc) as rnk
from CLV_calculation 
)
select *
from ranking 
where rnk < 11

--- The top CLV customers are the business's highest historical revenue generators.
--- Since this simplified CLV equals total delivered spend, the ranking is expected to match Q3's top spenders.
--- These customers should be prioritized for retention, but this is not a true predictive CLV metric

--- 35. Average rating alone doesn't tell the full story. Which agents have the highest variance in ratings (sometimes 5, sometimes 1)?
---  Who is the most consistent performer regardless of average?

with variance_calculation as (
select 	d.agent_id,
		count(d.order_id) as no_of_orders,
		round(variance(d.delivery_rating), 2) as variance
from deliveries d 
left join delivery_agents da 
on d.agent_id = da.agent_id
where lower(trim(d.delivery_status)) = 'delivered'
group by d.agent_id 
),
ranking as (
select *, dense_rank() over (order by variance asc NULLS LAST) as rnk
from variance_calculation
)
select * 
from ranking
where rnk = 1 

--- These are the most consistent performers regardless of average. 
--- However, to find the true value of each agent, we have to do a trend analysis that covers average delivery rating per agent for the quality, variance for consistency and no. of orders for volume (quantity) and number of observations.

--- 36. Are there any orders with status 'Cancelled' in the orders table that somehow still have a record in the deliveries table? 
--- What does this mean operationally — payment refund risk, data pipeline bug, or both?

select 	d.delivery_status, 	
		o.order_id,
    	o.status
from deliveries d
join orders o 
on d.order_id = o.order_id 
where lower(trim(o.status)) = 'cancelled'

--- No cancelled orders were found with corresponding delivery records.
--- Therefore, this dataset shows no evidence of the specific operational anomaly described in the question, and no payment/refund or pipeline risk can be inferred from this scenario.

--- 37. On which specific dates did revenue spike the most compared to the day before? 
--- Is the spike driven by order volume or by high-value individual orders? Are the spikes explainable?

WITH daily_gmv AS (
    SELECT
        TO_DATE(o.order_date, 'YYYY-MM-DD') AS order_date,
        COUNT(o.order_id) AS order_volume,
        SUM(o.order_amount) AS current_gmv,
        LAG(COUNT(o.order_id)) OVER (
            ORDER BY TO_DATE(o.order_date, 'YYYY-MM-DD')
        ) AS previous_order_volume,
        LAG(SUM(o.order_amount)) OVER (
            ORDER BY TO_DATE(o.order_date, 'YYYY-MM-DD')
        ) AS previous_gmv
    FROM orders o
    WHERE LOWER(TRIM(o.status)) = 'delivered'
    GROUP BY order_date
),
spikes AS (
    SELECT *,
        current_gmv - previous_gmv AS absolute_spike,
        ROUND(
            (current_gmv - previous_gmv) * 100.0 / NULLIF(previous_gmv, 0),
            2
        ) AS spike_percentage,
        DENSE_RANK() OVER ( ORDER BY (current_gmv - previous_gmv) * 100.0 / NULLIF(previous_gmv, 0) DESC NULLS LAST ) AS rnk
    FROM daily_gmv
),
restaurant_daily AS (
    SELECT
        TO_DATE(o.order_date, 'YYYY-MM-DD') AS order_date,
        o.restaurant_id,
        COUNT(o.order_id) AS order_volume,
        SUM(o.order_amount) AS restaurant_gmv
    FROM orders o
    WHERE LOWER(TRIM(o.status)) = 'delivered'
    GROUP BY
        order_date,
        o.restaurant_id
)
SELECT
    s.order_date AS spike_date,
    s.previous_gmv,
    s.current_gmv,
    s.absolute_spike,
    s.spike_percentage,
    r.order_date,
    r.restaurant_id,
    r.order_volume,
    r.restaurant_gmv
FROM spikes s
JOIN restaurant_daily r
    ON r.order_date IN (
        s.order_date,
        s.order_date - INTERVAL '1 day'
    )
ORDER BY
    s.rnk,
    r.order_date,
    r.restaurant_gmv DESC;

--- The spike was driven by a change in restaurant mix: the previous day's order was from a relatively low-value restaurant, while the spike day's order came from a higher-value restaurant. 
--- Since order volume remained unchanged, the increase in GMV was entirely attributable to the higher value of the order.

--- 38. For customers who ordered more than once, what is the average number of days between their first and second order?
--- Are customers who re-order faster also higher spenders overall?

with dates_cleaned as (
select	o.customer_id,	
		o.order_amount,
		to_date(o.order_date , 'yyyy-MM-dd') as cleaned_dates,
		row_number() over (partition by customer_id order by to_date(o.order_date , 'yyyy-MM-dd') asc) as order_number
from orders o
where lower(trim(o.status)) = 'delivered'
order by o.customer_id  asc
),
order_dates as (
SELECT
    customer_id,
    MAX(CASE
        WHEN order_number = 1
        THEN cleaned_dates 
    END) AS first_order_date,
    MAX(CASE
        WHEN order_number = 2
        THEN cleaned_dates 
    END) AS second_order_date, 
    sum(order_amount) as total_spend
from dates_cleaned
group by customer_id 
)
select *, second_order_date - first_order_date as days_to_reorder
from order_dates 
order by total_spend desc

--- 39. Are there customers ordering from restaurants in a different city than their home city? List them.
--- Is this a data issue, or do they genuinely order cross-city? What business rule should govern this?

with customer_order_details as (
select 	o.customer_id,
		o.order_id,
		lower(trim(c.city)) as cleaned_customer_city,
		lower(trim(r.city)) as cleaned_restaurant_city
from orders o 
left join customers c
on o.customer_id = c.customer_id 
left join restaurants r 
on o.restaurant_id = r.restaurant_id 
),
city_cleaning as (
select customer_id, order_id,
		case when cleaned_customer_city = 'pondy' then 'pondicherry' else cleaned_customer_city end as extra_cleaned_c_city, cleaned_restaurant_city 
from customer_order_details 
)
select *
from city_cleaning 
where extra_cleaned_c_city != cleaned_restaurant_city 
order by customer_id 

--- A customer's home city and restaurant city do not need to match. 
--- Cross-city orders should be considered valid unless the business explicitly restricts orders to the customer's home city or there is a separate delivery-address field that shows the order could not physically be fulfilled.

--- 40. Do orders with longer delivery times consistently receive lower ratings? 
--- Find the average rating for delivery time buckets: under 30 min, 30–45 min, 45–60 min, and 60+ min. Is the relationship linear?

with bucket_creation as (
select  d.delivery_rating,   
		case when o.delivery_time_minutes < 30 then 'fast_delivery'
			 when o.delivery_time_minutes between 30 AND 44 then 'medium_delivery'
			 when o.delivery_time_minutes BETWEEN 45 and 59 then 'slow_delivery'
		 	 when o.delivery_time_minutes >= 60 then 'very_slow_delivery'
		else 'unknown'
		end as pace_bucket
from orders o 
left join deliveries d 
on o.order_id = d.order_id 
where lower(trim(o.status)) = 'delivered'
)
select round(AVG(delivery_rating), 2) as average_rating_per_bucket,
		pace_bucket
from bucket_creation 
group by pace_bucket 
order by average_rating_per_bucket desc

--- Orders that have the shortest delivery time lead the table. However, we can not say this relationship is linear as 'very_slow_delivery' bucket has more avg rating than 'slow_delivery' bucket has.

--- 41. If you join orders → deliveries → agents without being careful about join type and aggregation level, revenue figures can be inflated. 
---  Construct a scenario where this double-counting happens and explain exactly why it occurs and how to fix it.

---The issue occurs because the orders table is at the order grain, where each order has one order_amount, while the deliveries table can be at the delivery-attempt grain, where one order can have multiple delivery records.
---When we join them, an order with multiple delivery attempts produces multiple rows. The order_amount is therefore repeated once for every matching delivery record.
---If we then use SUM(order_amount), SQL sums these repeated values and inflates the revenue.
---For example, an order worth ₹500 with three delivery attempts will appear as three rows after the join, causing SUM(order_amount) to return ₹1,500 instead of ₹500.
---The solution is to calculate revenue at the order grain, ensuring that each order contributes its revenue only once, and only then join to more detailed delivery or agent data if required.

--- 42. Create a simple efficiency score for each restaurant: (number of delivered orders ÷ total orders placed) × average delivery rating. 
---  Which restaurants score highest and lowest? What operational decisions would you make based on this?

with components_needed_for_metric as (
select  r.restaurant_id,
		count(case when lower(trim(o.status)) = 'delivered' then 1 end) as delivered_counting,
		count(*) as total_orders,
		round (AVG(d.delivery_rating), 2) as restaurant_avg_rating
from orders o 
left join restaurants r
on o.restaurant_id = r.restaurant_id 
left join deliveries d 
on o.order_id = d.order_id 
group by r.restaurant_id 
order by r.restaurant_id 
)
select *,
		round(delivered_counting * restaurant_avg_rating / total_orders, 2)  as efficiency_score
from components_needed_for_metric 

--- For operational decisions:
---Highest score: maintain current operations, potentially use it as a benchmark for other restaurants.
---Low delivery rate + low rating: major operational problem. Investigate cancellations, preparation delays, delivery-partner issues, etc.
---High delivery rate + low rating: orders are getting delivered, but the customer experience is poor. Investigate food quality, packaging, delays, or delivery handling.
---Low delivery rate + high rating: ratings are good when deliveries happen, but too many orders aren't being completed. Focus on fulfillment/cancellation issues.

--- 43. Identify customers who spent more than ₹2000 in total but placed their last order more than 45 days before the end of the dataset period. 
--- These are high-value customers showing signs of churn. How many are there and from which cities do they come?

with required_info as (
select  o.customer_id, 
		max(to_date(o.order_date, 'yyyy-MM-dd')) over(partition by o.customer_id) as last_order_date, 
		max(to_date(o.order_date, 'yyyy-MM-dd')) over() as last_date, 
		SUM(o.order_amount) over(partition by o.customer_id) as total_spent
from orders o 
)
select distinct customer_id
from required_info 
where total_spent > 2000 and last_date - last_order_date > 45

--- 44. Segment all customers into: One-Time (1 order), Occasional (2–3 orders), Regular (4+ orders). What share of total revenue does each segment drive?
--- If you could only run one re-engagement campaign, which segment would you target and why?

with customer_segmentation as (
select	o.customer_id,
		case when count(o.order_id) over(partition by o.customer_id) = 1 then 'One_time_customer' 
			 when count(o.order_id) over(partition by o.customer_id) between 2 and 3 then 'Occasional_customer'
			 when count(o.order_id) over(partition by o.customer_id) >= 4 then 'Regular_customer'
			 end as customer_type,
		o.order_id,
		o.order_amount
from orders o 
where lower(trim(o.status)) = 'delivered'
),
rev_segment as (
select customer_type, SUM(order_amount) as rev_per_segement
from customer_segmentation 
group by customer_type
)
select  customer_type,
        rev_per_segement,
        ROUND(rev_per_segement * 100.0 / SUM(rev_per_segement) OVER (), 2) AS revenue_share_pct
FROM rev_segment

--- The recommended target for a re-engagement campaign is occasional customers as they provide almost 80% of the total gmv.

--- 45. There are orders where order_amount is NULL. If you calculate total revenue with a simple SUM, these rows are silently excluded. 
--- How much revenue is potentially missing from your reports because of this? What should the business do — impute, flag, or exclude?

with restaurant_metrics as (
    select
        o.restaurant_id,
        AVG(o.order_amount) AS avg_order_amount,
        COUNT(*) FILTER (where o.order_amount IS NULL) as missing_orders
    from orders o
    group by o.restaurant_id
)
select  restaurant_id,
    	avg_order_amount,
    	missing_orders,
    	avg_order_amount * missing_orders AS potential_missing_revenue
from restaurant_metrics
WHERE missing_orders > 0;

--- The exact revenue loss cannot be determined because the actual amounts for NULL orders are unavailable. 
--- However, potential missing revenue can be estimated by multiplying each restaurant's average known order amount by its number of orders with NULL amounts. 
--- These estimates should not be treated as actual revenue. The NULL records should be flagged as a data-quality issue and investigated at the source. 
--- For official revenue reporting, I would exclude NULL amounts rather than silently impute them, while separately reporting the potential revenue exposure.

--- 46. Are any delivery agents handling orders in a city different from the city they are registered in? 
--- List those deliveries. Is this a routing system failure, agent flexibility, or a data entry error?

with joining_cte as (
select	o.order_id,
		da.agent_id,
		lower(trim(da.city)) as agent_city,
		lower(trim(r.city)) as restaurant_city
from orders o  
left join restaurants r
on o.restaurant_id = r.restaurant_id 
left join deliveries d 
on d.order_id = o.order_id 
left join delivery_agents da 
on d.agent_id = da.agent_id 
)
select *
from joining_cte
where agent_city <> restaurant_city

--- This is a cross-city delivery mismatch, 
--- but the dataset alone cannot determine whether it represents routing failure, legitimate agent flexibility, or incorrect agent master data.
--- Next investigation: Verify the business rule for agent operating areas, check Agent 14's actual operating location, examine the timing of the deliveries, 
--- and inspect the assignment/routing logic if cross-city deliveries are not permitted..

--- 47. Calculate the month-over-month revenue growth rate for Jan→Feb and Feb→Mar. 
--- Is the business growing? Now recalculate excluding cancelled orders and orders with NULL amounts. Does the growth story change?

with rev_segmentation as (
select
		DATE_TRUNC('month', to_date(o.order_date, 'yyyy-MM-dd')) as cleaned_dates,
		sum(o.order_amount) as monthly_rev
from orders o
where lower(trim(o.status)) = 'delivered'
group by cleaned_dates 
),
revenue_growth as (
select *,
		monthly_rev - lag(monthly_rev) over(order by cleaned_dates asc)  as rev_diff,
		100.0 * (monthly_rev - lag(monthly_rev) over(order by cleaned_dates asc)) / lag(monthly_rev) over(order by cleaned_dates asc) as rev_growth
from rev_segmentation
)
select 
	case when cleaned_dates = '2024-02-01 00:00:00.000 +0530' then 'jan-feb'
	     when cleaned_dates = '2024-03-01 00:00:00.000 +0530' then 'feb-march'
	     else null
	     end as cohort,
	 rev_growth
from revenue_growth 

--- 48. Among customers who only ordered in January and never again, what percentage had at least one cancelled order in January? 
--- Is cancellation a leading indicator of churn in this dataset?

with customer_orders as (
    select 
        o.customer_id,
        date_trunc('month', to_date(o.order_date, 'yyyy-MM-dd')) as order_month,
        lower(trim(o.status)) as order_status
    from orders o
),
customer_activity as (
    select 
        customer_id,
        min(order_month) as first_month,
        max(order_month) as last_month,
        max(case when order_month = '2024-01-01' and order_status = 'cancelled' then 1 else 0 end) as had_jan_cancellation
    from customer_orders
    group by customer_id
)
select 
    count(*) as total_jan_only_customers,
    sum(had_jan_cancellation) as jan_only_with_cancellation,
    round(100.0 * sum(had_jan_cancellation) / count(*), 2) as pct_with_cancellation
from customer_activity
where first_month = '2024-01-01' 
  and last_month = '2024-01-01';

--- 49. You are asked to build a monthly agent leaderboard. A junior analyst ranks agents purely by average rating. 
--- What are at least 3 reasons this leaderboard is misleading? Redesign the ranking criteria to be fairer and more operationally meaningful.
	
WITH agent_metrics AS (
    SELECT
        d.agent_id,
        COUNT(DISTINCT o.order_id) AS order_volume,
        ROUND(AVG(d.delivery_rating), 2) AS avg_rating,
        VAR_POP(d.delivery_rating) AS rating_variance
    FROM deliveries d
    LEFT JOIN orders o
        ON d.order_id = o.order_id
    GROUP BY d.agent_id
),
benchmarks AS (
    SELECT
        MAX(order_volume) AS max_order_volume,
        MAX(rating_variance) AS max_variance
    FROM agent_metrics
),
agent_scores AS (
SELECT
        a.*,
        ROUND(
            a.avg_rating / 5.0,
            3
        ) AS quality_score,
        ROUND(
            a.order_volume::numeric / b.max_order_volume,
            3
        ) AS volume_score,
        ROUND(
            1 - (
                a.rating_variance / NULLIF(b.max_variance, 0)
            ),
            3
        ) AS consistency_score
    FROM agent_metrics a
    CROSS JOIN benchmarks b
)
SELECT
    agent_id,
    order_volume,
    avg_rating,
    ROUND(rating_variance, 3) AS rating_variance,
    quality_score,
    volume_score,
    consistency_score,
    ROUND(
        (
            quality_score * 0.50
            + volume_score * 0.30
            + consistency_score * 0.20
        ),
        3
    ) AS agent_score
FROM agent_scores
ORDER BY agent_score DESC;

--- 50. The CEO wants a single-page business summary for Q1 2024 (Jan–Mar). 
--- Using only this dataset, define the 6 most important KPIs you would report, the biggest risk you would flag, one growth opportunity you see, and one data quality issue that might be distorting the numbers.
--- Justify every choice.

select
    r.restaurant_id,
    r.restaurant_name,
    round(avg(d.delivery_rating), 2) as avg_rating,
    round(avg(o.delivery_time_minutes), 2) as avg_delivery_time,
    count(distinct case when date_trunc('month', to_date(o.order_date, 'YYYY-MM-DD')) = '2024-01-01' then o.order_id end) as jan_orders,
    count(distinct case when date_trunc('month', to_date(o.order_date, 'YYYY-MM-DD')) = '2024-02-01' then o.order_id end) as feb_orders,
    count(distinct case when date_trunc('month', to_date(o.order_date, 'YYYY-MM-DD')) = '2024-03-01' then o.order_id end) as mar_orders
from orders o
join restaurants r
    on o.restaurant_id = r.restaurant_id
left join deliveries d
    on d.order_id = o.order_id
where lower(trim(r.city)) = 'chennai'
    and lower(trim(o.status)) = 'delivered'
group by r.restaurant_id, r.restaurant_name
order by mar_orders asc;
