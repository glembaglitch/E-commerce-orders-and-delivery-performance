create schema olistecommerce;

set search_path to olistecommercedata;

create table customers (
customer_id varchar(40) primary key,
customer_unique_id varchar(40),
customer_zip_code_prefix varchar (7),
customer_city text,
customer_state char(2));

select * from customers;

create table orders(
order_id varchar (40) primary key,
customer_id varchar(40),
order_status text,
order_purchase_timestamp timestamp,
order_approved_at timestamp,
order_delivered_carrier_date timestamp,
order_delivered_customer_date timestamp,
order_estimated_delivery_date timestamp);

select * from orders;

create table order_items(
order_id varchar(40),
order_item_id int,
product_id varchar (40),
seller_id varchar (40),
shipping_limit_date timestamp,
price numeric (10, 2),
freight_value numeric (10, 2),
primary key (order_id, order_item_id),
foreign key (order_id) references orders(order_id));

select * from order_items;

--Checking for nulls
select 
  count(*) filter (where order_id is null) as null_order_id,
  count(*) filter (where customer_id is null) as null_customer_id,
  count(*) filter (where order_status is null) as null_order_status,
  count(*) filter (where order_purchase_timestamp is null) as null_purchase_timestamp,
  count(*) filter (where order_approved_at is null) as null_approved_at,
  count(*) filter (where order_delivered_carrier_date is null) as null_carrier_date,
  count(*) filter (where order_delivered_customer_date is null) as null_delivered_date,
  count(*) filter (where order_estimated_delivery_date is null) as null_estimated_delivery_date
from orders;
--All nulls are on date columns hence can't be filled with guessed digits(can be left the way they are)

--Total revenue and order count
select 
  count(distinct order_id) as total_orders,
  sum(price) as total_product_revenue,
  sum(freight_value) as total_freight_revenue,
  sum(price + freight_value) as total_gross_revenue
from order_items;

--Monthly sales
select 
  date_trunc('month', o.order_purchase_timestamp) as order_month,
  count(distinct o.order_id) as total_orders,
  round(sum(oi.price), 2) as total_product_revenue,
  round(sum(oi.freight_value), 2) as total_freight_revenue,
  round(sum(oi.price + oi.freight_value), 2) as total_gross_revenue
from orders o
join order_items oi ON o.order_id = oi.order_id
where o.order_status = 'delivered'
group by 1
order by order_month asc;

--Monthly revenue growth trend
with monthly_revenue AS (
    select
        date_trunc('month', o.order_purchase_timestamp)::date as month,
        count(distinct o.order_id) as order_count,
        sum(oi.price + oi.freight_value) as revenue
    from orders as o
    join order_items as oi
        on oi.order_id = o.order_id
    where o.order_status = 'delivered'
    group by 1
),
calendar as (
    select generate_series(
        (select min(month) from monthly_revenue)::timestamp,
        (select max(month) from monthly_revenue)::timestamp,
        interval '1 month'
    )::date as month
),
monthly as (
    select
        calendar.month,
        coalesce(monthly_revenue.order_count, 0) as order_count,
        coalesce(monthly_revenue.revenue, 0) as revenue
    from calendar
    left join monthly_revenue using (month)
),
with_previous_month as (
    select
        month,
        order_count,
        revenue,
        lag(revenue) over (order by month) as previous_month_revenue
    from monthly
)
select
    month,
    order_count,
    round(revenue, 2) as revenue,
    round(previous_month_revenue, 2) as previous_month_revenue,
    round(revenue - previous_month_revenue, 2) as revenue_change,
    round(
        100.0 * (revenue - previous_month_revenue)
        / nullif(previous_month_revenue, 0),
        2
    ) as growth_percent
from with_previous_month
order by month;
--The first's month revevue change and groth_percenr are null because there is no previous month to compare with

--Frequent customers
with customer_orders_count as (
  select 
    c.customer_unique_id,
    count(distinct o.order_id) as total_orders_count
  from customers as c
  join orders as o 
    on o.customer_id = c.customer_id 
  where o.order_status = 'delivered'
  group by c.customer_unique_id
)
select
  count(*) as unique_customers,
  count(*) filter (where total_orders_count > 1) as frequent_customers,
  round(count(*) filter (where total_orders_count > 1) * 100.0 / nullif(count(*), 0), 2) as frequent_customers_percentage
from customer_orders_count;

--Delivery delays
select 
  o.order_id,
  c.customer_state,
  o.order_purchase_timestamp,
  o.order_delivered_customer_date,
  o.order_estimated_delivery_date,
  extract(day from(o.order_delivered_customer_date - order_purchase_timestamp)) as delivery_days,
  extract(day from(o.order_estimated_delivery_date - o.order_delivered_customer_date)) as days_from_estimate,
  case when o.order_delivered_customer_date > o.order_estimated_delivery_date then 1 end as late_deliveries
from orders o 
join customers c 
  on o.customer_id = c.customer_id
where o.order_status = 'delivered'
  and o.order_delivered_customer_date is not null; 

--Customers acquisition and repeat purchase rates
with customer_orders as (
  select 
    c.customer_unique_id,
    o.order_id,
    o.order_purchase_timestamp,
    lag(o.order_purchase_timestamp) over(
      partition by c.customer_unique_id
      order by o.order_purchase_timestamp) as previous_order_date
  from orders o
  join customers c 
    on o.customer_id = c.customer_id)
select 
  customer_unique_id,
  order_id,
  order_purchase_timestamp,
  previous_order_date,
  extract(day from (order_purchase_timestamp - previous_order_date)) as days_since_last_order
from customer_orders 
where previous_order_date is not null;

--Customer segmentation(Recency, Frequency, Monetary(RFM)
with rfm as (
  select 
    c.customer_unique_id,
    max(o.order_purchase_timestamp) as last_order_date,
    count(distinct o.order_id) as frequency,
    sum(oi.price) as monetary
  from customers c
  join orders o on
    c.customer_id = o.customer_id
  join order_items oi on 
    o.order_id = oi.order_id 
  where o.order_status = 'delivered'
  group by c.customer_unique_id
),  
rfm_scores as (
  select 
    customer_unique_id,
    ntile(5) over (order by last_order_date asc) as r_score,
    ntile(5) over (order by frequency asc) as f_score,
    ntile(5) over (order by monetary asc) as m_score
  from rfm
)
select 
  customer_unique_id,
  r_score, f_score, m_score,
  case 
  	when r_score >= 4 and f_score >=4 and m_score >= 4 then 'Dedicated Customer'
  	when r_score >=3 and m_score >=3 then 'Loyal Customer'
  	when r_score <=2 and m_score >=4 then 'Valuable Customer'
  	else 'Standard Customer'
  end as customer_segment
from rfm_scores;

--High value customer locations
select 
  c.customer_state,
  count(distinct o.order_id) as total_orders,
  round(sum(oi.price), 2) as total_revenue,
  round(avg(oi.price), 2) as avrg_item_price
from customers c
join orders o 
  on c.customer_id = o.customer_id 
join order_items oi 
  on o.order_id = oi.order_id 
where o.order_status = 'delivered'
group by c.customer_state 
order by total_revenue desc;
  
  
