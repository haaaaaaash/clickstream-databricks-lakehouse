-- src_products: rename + cast only, no business logic
select
    product_id,
    category,
    name                               as product_name,
    cast(price_usd as decimal(10,2))   as price_usd,
    cast(cost_usd as decimal(10,2))    as cost_usd,
    cast(margin_usd as decimal(10,2))  as margin_usd
from {{ source('bronze', 'products') }}
