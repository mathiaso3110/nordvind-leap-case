-- Aggregated to grid area and day, so no meter or customer identifier survives
-- into this table. The cheapest access control is not propagating the data:
-- this mart needs no masking policy at all.

select
    grid_area,
    date(read_at_utc)         as reading_date,
    count(*)                  as reading_count,
    sum(consumption_kwh)      as consumption_kwh
from {{ ref('stg_meter_readings') }}
group by 1, 2
