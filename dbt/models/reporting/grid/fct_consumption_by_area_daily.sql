-- Aggregated to area and day, so no meter or CPR survives into this table.
-- The cheapest access control is not propagating the data: this model needs no
-- masking policy at all.

select
    region,
    subregion,
    date(read_at_utc)    as reading_date,
    count(*)             as reading_count,
    sum(consumption_kwh) as consumption_kwh
from {{ ref('stg_meter_readings') }}
group by 1, 2, 3
