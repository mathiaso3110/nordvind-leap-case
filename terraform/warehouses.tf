# One warehouse per team, so QUERY_ATTRIBUTION_HISTORY and the resource monitors
# both attribute spend to a team without any tagging discipline from users.
# 60s auto-suspend everywhere: credits are billed per second after the first
# minute, so an idle warehouse is pure waste.

resource "snowflake_warehouse" "finance" {
  name           = "WH_FINANCE"
  warehouse_size = "XSMALL"
  auto_suspend   = 60
  auto_resume    = true
  comment        = "Finance reporting queries."
}

resource "snowflake_warehouse" "grid" {
  name           = "WH_GRID"
  warehouse_size = "SMALL"
  auto_suspend   = 60
  auto_resume    = true
  comment        = "Grid Operations telemetry. Higher volume than reporting."
}

# The one that caused the bill. Monitor suspends it rather than trusting people
# to notice.
resource "snowflake_warehouse" "datascience" {
  name             = "WH_DATASCIENCE"
  warehouse_size   = "MEDIUM"
  auto_suspend     = 60
  auto_resume      = true
  resource_monitor = snowflake_resource_monitor.datascience.name
  comment          = "Data Science. Capped by a resource monitor."
}

resource "snowflake_warehouse" "transform" {
  name           = "WH_TRANSFORM"
  warehouse_size = "XSMALL"
  auto_suspend   = 60
  auto_resume    = true
  comment        = "dbt only. Heavy models route here via snowflake_warehouse configs."
}

# Monitors are not precise and take minutes to act, so the suspend threshold
# needs headroom
resource "snowflake_resource_monitor" "datascience" {
  name                      = "RM_DATASCIENCE"
  credit_quota              = 20
  frequency                 = "MONTHLY"
  start_timestamp           = "IMMEDIATELY"
  notify_triggers           = [75, 90]
  suspend_trigger           = 100
  suspend_immediate_trigger = 110
}
