with source as (
    select * from {{ source('raw', 'offers') }}
),

cleaned as (
    select
        offer_id,
        offer_type,
        difficulty      as min_spend,
        reward          as reward_amount,
        duration        as duration_days,
        channels
    from source
)

select * from cleaned