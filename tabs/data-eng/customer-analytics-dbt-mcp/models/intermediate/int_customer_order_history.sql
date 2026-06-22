select
    customers.customer_id,
    customers.customer_name,
    customers.email,
    customers.signup_date,
    customers.state,
    customers.marketing_channel,

    min(orders.order_date) filter (where orders.status = 'completed') as first_order_date,
    max(orders.order_date) filter (where orders.status = 'completed') as last_order_date,

    count(orders.order_id) as total_orders,
    count(orders.order_id) filter (where orders.status = 'completed') as completed_orders,
    count(orders.order_id) filter (where orders.status = 'refunded') as refunded_orders,
    count(orders.order_id) filter (where orders.status = 'cancelled') as cancelled_orders,

    coalesce(sum(orders.net_order_revenue), 0) as lifetime_revenue,
    coalesce(avg(orders.net_order_revenue) filter (where orders.status = 'completed'), 0) as avg_completed_order_value

from {{ ref('stg_customers') }} as customers
left join {{ ref('int_order_revenue') }} as orders
    on customers.customer_id = orders.customer_id
group by
    customers.customer_id,
    customers.customer_name,
    customers.email,
    customers.signup_date,
    customers.state,
    customers.marketing_channel
