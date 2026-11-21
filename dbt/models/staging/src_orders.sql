-- src_orders: rename + cast only, no business logic
select
    order_id,
    customer_id,
    try_to_timestamp(order_time)        as ordered_at,       -- ISO 8601 text
    payment_method,
    cast(discount_pct as decimal(5,2))  as discount_pct,
    cast(subtotal_usd as decimal(10,2)) as subtotal_usd,
    cast(total_usd as decimal(10,2))    as total_usd,
    country,
    device,
    source                              as traffic_source
from {{ source('bronze', 'orders') }}
