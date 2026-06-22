select
    order_item_id::integer as order_item_id,
    order_id::integer as order_id,
    product_id::integer as product_id,
    quantity::integer as quantity,
    unit_price::numeric(10,2) as unit_price,
    quantity::integer * unit_price::numeric(10,2) as gross_item_revenue
from {{ ref('order_items') }}
