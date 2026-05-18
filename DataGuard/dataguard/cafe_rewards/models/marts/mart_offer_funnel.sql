with events as (
    select * from {{ ref('stg_events') }}
),

received as (
    select offer_id, count(distinct customer_id) as received_count
    from events
    where event_type = 'offer received'
    group by offer_id
),

viewed as (
    select offer_id, count(distinct customer_id) as viewed_count
    from events
    where event_type = 'offer viewed'
    group by offer_id
),

completed as (
    select offer_id, count(distinct customer_id) as completed_count
    from events
    where event_type = 'offer completed'
    group by offer_id
),

offers as (
    select * from {{ ref('stg_offers') }}
)

select
    o.offer_id,
    o.offer_type,
    o.min_spend,
    o.reward_amount,
    o.duration_days,
    o.channels,
    coalesce(r.received_count, 0)   as received_count,
    coalesce(v.viewed_count, 0)     as viewed_count,
    coalesce(c.completed_count, 0)  as completed_count,
    round(coalesce(v.viewed_count, 0) / nullif(r.received_count, 0) * 100, 2) as view_rate_pct,
    round(coalesce(c.completed_count, 0) / nullif(r.received_count, 0) * 100, 2) as completion_rate_pct
from offers o
left join received r on o.offer_id = r.offer_id
left join viewed v on o.offer_id = v.offer_id
left join completed c on o.offer_id = c.offer_id