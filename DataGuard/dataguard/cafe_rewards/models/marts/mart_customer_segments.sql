with customers as (
    select * from {{ ref('stg_customers') }}
),

events as (
    select * from {{ ref('stg_events') }}
),

customer_transactions as (
    select
        customer_id,
        count(*)                        as total_transactions,
        sum(transaction_amount)         as total_spend,
        avg(transaction_amount)         as avg_transaction_value
    from events
    where event_type = 'transaction'
    group by customer_id
)

select
    c.customer_id,
    c.gender,
    c.age,
    c.income,
    c.member_since,
    c.membership_days,
    case
        when c.income < 40000 then 'Low'
        when c.income < 80000 then 'Medium'
        when c.income >= 80000 then 'High'
        else 'Unknown'
    end                                 as income_segment,
    case
        when c.age < 30 then 'Under 30'
        when c.age < 45 then '30-44'
        when c.age < 60 then '45-59'
        when c.age >= 60 then '60+'
        else 'Unknown'
    end                                 as age_segment,
    coalesce(t.total_transactions, 0)   as total_transactions,
    coalesce(t.total_spend, 0)          as total_spend,
    coalesce(t.avg_transaction_value,0) as avg_transaction_value
from customers c
left join customer_transactions t on c.customer_id = t.customer_id