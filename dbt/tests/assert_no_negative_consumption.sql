-- Consumption can be zero but never negative. A negative value means the
-- upstream feed is wrong, not that a household exported power — export is a
-- separate meter register.
-- Singular test rather than dbt_utils.accepted_range: three lines beats a package.

select region, subregion, reading_date, consumption_kwh
from {{ ref('fct_consumption_by_area_daily') }}
where consumption_kwh < 0
