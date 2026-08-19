// What the money buys, per team. WAREHOUSE_METERING_HISTORY lags up to 3 hours.
//
// A warehouse per team means this needs no query tags and no cooperation from
// users — the split is structural.

use role accountadmin;
use warehouse wh_transform;


// --- Credits per team, last 30 days ---------------------------------------

select
    warehouse_name,
    round(sum(credits_used), 3)                    as credits,
    round(sum(credits_used_compute), 3)            as compute,
    round(sum(credits_used_cloud_services), 3)     as cloud_services,
    count(distinct date(start_time))               as active_days
from snowflake.account_usage.warehouse_metering_history
where start_time >= dateadd(day, -30, current_timestamp())
group by 1
order by credits desc;


// --- Idle: metered minus attributed ---------------------------------------
// QUERY_ATTRIBUTION_HISTORY only counts credits a query is responsible for. The
// difference is a warehouse running while nobody queried it — usually the real
// villain, and invisible if you only look at per-query cost.

with metered as (
    select warehouse_name, sum(credits_used_compute) as metered_credits
    from snowflake.account_usage.warehouse_metering_history
    where start_time >= dateadd(day, -30, current_timestamp())
    group by 1
),
attributed as (
    select warehouse_name, sum(credits_attributed_compute) as query_credits
    from snowflake.account_usage.query_attribution_history
    where start_time >= dateadd(day, -30, current_timestamp())
    group by 1
)
select
    m.warehouse_name,
    round(m.metered_credits, 3)                             as metered,
    round(coalesce(a.query_credits, 0), 3)                  as attributed_to_queries,
    round(m.metered_credits - coalesce(a.query_credits, 0), 3) as idle,
    round(100 * (m.metered_credits - coalesce(a.query_credits, 0))
          / nullif(m.metered_credits, 0), 1)                as idle_pct
from metered m
left join attributed a on a.warehouse_name = m.warehouse_name
order by idle desc;


// --- Daily trend, per team -------------------------------------------------
// The shape the CFO asked for: is it growing, and whose.

select
    date(start_time)                    as day,
    warehouse_name,
    round(sum(credits_used), 3)         as credits
from snowflake.account_usage.warehouse_metering_history
where start_time >= dateadd(day, -14, current_timestamp())
group by 1, 2
order by 1 desc, credits desc;


// --- Where the monitor stands ---------------------------------------------
// Resource monitors cover warehouses only. Serverless spend needs Budgets.

show resource monitors;
