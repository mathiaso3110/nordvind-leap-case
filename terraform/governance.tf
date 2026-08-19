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

# IS_ROLE_IN_SESSION, not CURRENT_ROLE(): current_role() returns the functional
# role the session did USE ROLE on, so it never matches an inherited access role
# and everyone would be masked. Row and masking policies deliberately use
# different functions — the row policy wants the primary role only, this wants
# inheritance.
resource "snowflake_masking_policy" "mask_cpr" {
  name             = "MASK_CPR"
  database         = snowflake_database.governance.name
  schema           = "PUBLIC"
  return_data_type = "VARCHAR"

  argument {
    name = "VAL"
    type = "VARCHAR"
  }

  body = "case when is_role_in_session('AR_PROD_SENSITIVE') then val else '******-****' end"

  comment = "CPR is visible only to roles holding AR_PROD_SENSITIVE. ACCOUNTADMIN included — a superuser has no business reading CPR casually."
}

# Applied to the RAW column. Views inherit it, so the dbt staging model is
# covered without any config of its own.
resource "snowflake_table_column_masking_policy_application" "cpr" {
  table          = snowflake_table.meter_readings.fully_qualified_name
  column         = "CPR"
  masking_policy = snowflake_masking_policy.mask_cpr.fully_qualified_name
}
