select
    orders.order_id,
    orders.customer_id,
    orders.order_date,
    orders.status,
    count(order_items.order_item_id) as item_count,
    sum(order_items.quantity) as total_units,
    sum(order_items.gross_item_revenue) as gross_order_revenue,
    case
        when orders.status = 'completed'
            then sum(order_items.gross_item_revenue)
        else 0
    end as net_order_revenue
from {{ ref('stg_orders') }} as orders
left join {{ ref('stg_order_items') }} as order_items
    on orders.order_id = order_items.order_id
group by
    orders.order_id,
    orders.customer_id,
    orders.order_date,
    orders.status
