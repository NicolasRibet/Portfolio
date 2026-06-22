select
    customer_id,
    customer_name,
    email,
    signup_date,
    state,
    marketing_channel,
    first_order_date,
    last_order_date,
    total_orders,
    completed_orders,
    refunded_orders,
    cancelled_orders,
    lifetime_revenue,
    avg_completed_order_value,

    case
        when lifetime_revenue >= 200 then 'high_value'
        when lifetime_revenue >= 100 then 'mid_value'
        when lifetime_revenue > 0 then 'low_value'
        else 'no_purchase'
    end as customer_segment

from {{ ref('int_customer_order_history') }}
