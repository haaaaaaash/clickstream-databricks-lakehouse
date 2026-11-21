-- src_sessions: rename + cast only, no business logic
select
    session_id,
    customer_id,
    try_to_timestamp(start_time)  as session_started_at,  -- ISO 8601 text
    device,
    source                        as traffic_source,
    country
from {{ source('bronze', 'sessions') }}
