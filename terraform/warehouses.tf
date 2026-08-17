# XS by default with a short auto-suspend. Heavy models get routed to a bigger
# warehouse per-model via dbt's snowflake_warehouse config, rather than sizing
# this one up for everyone.
resource "snowflake_warehouse" "transforming" {
  name           = "TRANSFORMING_WH"
  warehouse_size = "XSMALL"
  auto_suspend   = 60
  auto_resume    = true
  comment        = "dbt transformations."
}
