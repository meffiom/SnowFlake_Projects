with source as (
    select * from {{ source('raw', 'events') }}
),

cleaned as (
    select
        customer_id,
        event           as event_type,
        time            as hours_elapsed,
        value           as raw_value,
        case
            when event in ('offer received','offer viewed','offer completed')
                then regexp_substr(value, '[a-f0-9]{32}')
            else null
        end             as offer_id,
        case
            when event = 'transaction'
                then try_cast(regexp_substr(value, '[0-9]+\\.[0-9]+') as float)
            else null
        end             as transaction_amount
    from source
)

select * from cleaned