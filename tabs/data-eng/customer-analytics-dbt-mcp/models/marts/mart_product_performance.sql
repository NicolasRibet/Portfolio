select
    products.product_id,
    products.product_name,
    products.category,
    products.is_active,

    count(distinct order_items.order_id) filter (where orders.status = 'completed') as completed_orders,
    sum(order_items.quantity) filter (where orders.status = 'completed') as units_sold,
    sum(order_items.gross_item_revenue) filter (where orders.status = 'completed') as gross_revenue,

    count(distinct order_items.order_id) filter (where orders.status = 'refunded') as refunded_orders,
    count(distinct order_items.order_id) filter (where orders.status = 'cancelled') as cancelled_orders

from {{ ref('stg_products') }} as products
left join {{ ref('stg_order_items') }} as order_items
    on products.product_id = order_items.product_id
left join {{ ref('stg_orders') }} as orders
    on order_items.order_id = orders.order_id
group by
    products.product_id,
    products.product_name,
    products.category,
    products.is_active
