-- src_customers: rename + cast only, no business logic
select
    customer_id,
    name                                                     as customer_name,
    email,
    country,
    age,
    cast(try_to_timestamp(signup_date, 'M/d/yyyy') as date)  as signup_date,          -- EDA #6: M/D/YYYY text
    marketing_opt_in                                         as is_marketing_opt_in   -- already BOOLEAN in Bronze
from {{ source('bronze', 'customers') }}
