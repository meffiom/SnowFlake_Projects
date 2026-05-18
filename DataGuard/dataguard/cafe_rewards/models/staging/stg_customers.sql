with source as (
    select * from {{ source('raw', 'customers') }}
),

cleaned as (
    select
        customer_id,
        to_date(became_member_on, 'YYYYMMDD')   as member_since,
        case gender
            when 'M' then 'Male'
            when 'F' then 'Female'
            when 'O' then 'Other'
            else null
        end                                      as gender,
        case when age = 118 then null
             else age
        end                                      as age,
        income,
        datediff('day',
            to_date(became_member_on, 'YYYYMMDD'),
            current_date())                      as membership_days
    from source
)

select * from cleaned