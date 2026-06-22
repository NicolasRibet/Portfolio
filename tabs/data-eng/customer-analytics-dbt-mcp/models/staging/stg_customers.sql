select
    customer_id::integer as customer_id,
    first_name,
    last_name,
    first_name || ' ' || last_name as customer_name,
    lower(email) as email,
    signup_date::date as signup_date,
    country,
    state,
    marketing_channel
from {{ ref('customers') }}
