resource "snowflake_database" "governance" {
  name    = "GOVERNANCE"
  comment = "Policies and tags. Separate database so policy ownership is its own grantable surface."
}

resource "snowflake_row_access_policy" "region_access" {
  name     = "REGION_ACCESS"
  database = snowflake_database.governance.name
  schema   = "PUBLIC"

  argument {
    name = "REGION"
    type = "VARCHAR"
  }

  body = <<-SQL
    case
      when current_role() in ('ACCOUNTADMIN', 'TRANSFORMER') then true
      when current_role() in ('GRID_OPS_DK1', 'DATA_SCIENCE_DK1') then region = 'DK1'
      when current_role() in ('GRID_OPS_DK2', 'DATA_SCIENCE_DK2') then region = 'DK2'
      else false
    end
  SQL

  comment = "Grid Ops and Data Science see their own price area. Finance gets aggregates, not rows."
}
