-- src_order_items: rename + cast only. NO dedup here: repeated lines are valid (EDA #4)
select
    order_id,
    product_id,
    cast(unit_price_usd as decimal(10,2))  as unit_price_usd,
    quantity,
    cast(line_total_usd as decimal(10,2))  as line_total_usd
from {{ source('bronze', 'order_items') }}
