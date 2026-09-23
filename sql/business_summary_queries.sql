-- food delivery analytics - q1 2024 business summary
-- reproduces the findings in business_summary.md


-- 1. monthly kpi summary
select
  date_trunc('month', to_date(o.order_date, 'yyyy-mm-dd')) as month,
  sum(o.order_amount) as revenue,
  count(o.order_id) as orders,
  round(avg(o.order_amount), 2) as avg_order_value,
  count(distinct o.customer_id) as active_customers
from orders o
where lower(trim(o.status)) = 'delivered'
group by month
order by month;


-- 2. revenue growth rate month over month
select
  date_trunc('month', to_date(o.order_date, 'yyyy-mm-dd')) as month,
  sum(o.order_amount) as revenue,
  round(
    100.0 * (sum(o.order_amount) - lag(sum(o.order_amount)) over (order by date_trunc('month', to_date(o.order_date, 'yyyy-mm-dd'))))
    / nullif(lag(sum(o.order_amount)) over (order by date_trunc('month', to_date(o.order_date, 'yyyy-mm-dd'))), 0),
    2
  ) as growth_rate_pct
from orders o
where lower(trim(o.status)) = 'delivered'
group by month
order by month;


-- 3. order volume and aov by month
select
  date_trunc('month', to_date(o.order_date, 'yyyy-mm-dd')) as month,
  count(o.order_id) as orders,
  round(avg(o.order_amount), 2) as aov
from orders o
where lower(trim(o.status)) = 'delivered'
group by month
order by month;


-- 4. order volume by region per month
select
  lower(trim(r.city)) as region,
  date_trunc('month', to_date(o.order_date, 'yyyy-mm-dd')) as month,
  count(o.order_id) as orders
from orders o
join restaurants r on o.restaurant_id = r.restaurant_id
where lower(trim(o.status)) = 'delivered'
group by region, month
order by region, month;


-- 5. revenue by region per month
select
  lower(trim(r.city)) as region,
  date_trunc('month', to_date(o.order_date, 'yyyy-mm-dd')) as month,
  sum(o.order_amount) as revenue
from orders o
join restaurants r on o.restaurant_id = r.restaurant_id
where lower(trim(o.status)) = 'delivered'
group by region, month
order by region, month;


-- 6. chennai - active customers and orders per customer by month
-- shows the decline is frequency, not churn
with chennai_orders as (
  select
    o.customer_id,
    date_trunc('month', to_date(o.order_date, 'yyyy-mm-dd')) as month
  from orders o
  join restaurants r on o.restaurant_id = r.restaurant_id
  where lower(trim(o.status)) = 'delivered'
    and lower(trim(r.city)) = 'chennai'
)
select
  month,
  count(distinct customer_id) as active_customers,
  count(*) as orders,
  round(count(*) * 1.0 / nullif(count(distinct customer_id), 0), 2) as orders_per_customer
from chennai_orders
group by month
order by month;


-- 7. restaurant-level order decline within chennai
-- shows the decline is spread, not one outlier
select
  r.restaurant_id,
  r.restaurant_name,
  date_trunc('month', to_date(o.order_date, 'yyyy-mm-dd')) as month,
  count(o.order_id) as orders
from orders o
join restaurants r on o.restaurant_id = r.restaurant_id
where lower(trim(o.status)) = 'delivered'
  and lower(trim(r.city)) = 'chennai'
group by r.restaurant_id, r.restaurant_name, month
order by r.restaurant_name, month;


-- 8. churned vs retained customers - aov, rating, delivery time
-- tests whether service quality explains churn
with jan_customers as (
  select distinct o.customer_id
  from orders o
  where to_date(o.order_date, 'yyyy-mm-dd') between '2024-01-01' and '2024-01-31'
    and lower(trim(o.status)) = 'delivered'
),
mar_customers as (
  select distinct o.customer_id
  from orders o
  where to_date(o.order_date, 'yyyy-mm-dd') between '2024-03-01' and '2024-03-31'
    and lower(trim(o.status)) = 'delivered'
),
churn_status as (
  select
    j.customer_id,
    case when m.customer_id is not null then 'retained' else 'churned' end as status
  from jan_customers j
  left join mar_customers m on j.customer_id = m.customer_id
)
select
  cs.status,
  round(avg(o.order_amount), 2) as avg_aov,
  round(avg(d.delivery_rating), 2) as avg_rating,
  round(avg(o.delivery_time_minutes), 2) as avg_delivery_time
from churn_status cs
join orders o on cs.customer_id = o.customer_id
left join deliveries d on o.order_id = d.order_id
where lower(trim(o.status)) = 'delivered'
group by cs.status;