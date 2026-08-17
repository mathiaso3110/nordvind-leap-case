-- Rename and recast once, here, so nothing downstream has to know what the
-- source system called things.

select
    meter_id,
    customer_id,
    grid_area,
    read_at        as read_at_utc,
    kwh            as consumption_kwh
from {{ source('metering', 'meter_readings') }}
