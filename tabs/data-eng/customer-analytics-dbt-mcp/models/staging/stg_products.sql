select
    product_id::integer as product_id,
    product_name,
    category,
    launch_date::date as launch_date,
    is_active::boolean as is_active
from {{ ref('products') }}
