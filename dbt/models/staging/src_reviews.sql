-- src_reviews: rename + cast only, no business logic
select
    review_id,
    order_id,
    product_id,
    rating,
    review_text,
    try_to_timestamp(review_time)  as reviewed_at       -- ISO 8601 text
from {{ source('bronze', 'reviews') }}
