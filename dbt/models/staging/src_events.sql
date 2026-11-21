-- src_events: rename + cast only, no business logic
select
    event_id,
    session_id,
    try_to_timestamp(`timestamp`)       as event_at,         -- ISO 8601 text
    event_type,
    cast(product_id as bigint)          as product_id,       -- EDA #5: stored as 93.0
    cast(qty as int)                    as quantity,
    cast(cart_size as int)              as cart_size,
    payment                             as payment_method,
    cast(discount_pct as decimal(5,2))  as discount_pct,
    cast(amount_usd as decimal(10,2))   as amount_usd
from {{ source('bronze', 'events') }}
