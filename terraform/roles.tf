# Functional roles: what a person or service *is*. Object privileges live on
# access roles (see grants.tf) and are granted into these. The DK1/DK2 split
# exists so the row access policy can key off CURRENT_ROLE().

locals {
  functional_roles = {
    TRANSFORMER      = "Identity dbt runs as. Reads RAW, builds PROD."
    FINANCE_ANALYST  = "Regulatory reporting. Aggregates only."
    GRID_OPS_DK1     = "Grid Operations, price area DK1."
    GRID_OPS_DK2     = "Grid Operations, price area DK2."
    DATA_SCIENCE_DK1 = "Data Science, price area DK1."
    DATA_SCIENCE_DK2 = "Data Science, price area DK2."
  }

  # Which compute each role may spend. Not routed through an access role: this is
  # a budget question, not an object-access one.
  warehouse_by_role = {
    TRANSFORMER      = snowflake_warehouse.transform.name
    FINANCE_ANALYST  = snowflake_warehouse.finance.name
    GRID_OPS_DK1     = snowflake_warehouse.grid.name
    GRID_OPS_DK2     = snowflake_warehouse.grid.name
    DATA_SCIENCE_DK1 = snowflake_warehouse.datascience.name
    DATA_SCIENCE_DK2 = snowflake_warehouse.datascience.name
  }
}

resource "snowflake_account_role" "functional" {
  for_each = local.functional_roles

  name    = each.key
  comment = each.value
}

resource "snowflake_grant_privileges_to_account_role" "warehouse_usage" {
  for_each = local.warehouse_by_role

  account_role_name = snowflake_account_role.functional[each.key].name
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "WAREHOUSE"
    object_name = each.value
  }
}

# Granted individually, not through a shared parent role: a parent would give
# every holder the union of all five roles' access, which is the opposite of
# what the DK1/DK2 split is for.
resource "snowflake_grant_account_role" "to_me" {
  for_each = local.functional_roles

  role_name = snowflake_account_role.functional[each.key].name
  user_name = "MATHIASO3110"
}

# Snowflake defaults new users to DEFAULT_SECONDARY_ROLES = ALL, which activates
# every granted role in every session. Privilege checks then pass through
# whichever role happens to allow it, so USE ROLE stops isolating anything and
# CURRENT_ROLE() policies disagree with what the session can actually read.
# Turning it off is what makes role switching mean something.
resource "snowflake_execute" "no_secondary_roles" {
  execute = "ALTER USER MATHIASO3110 SET DEFAULT_SECONDARY_ROLES = ()"
  revert  = "ALTER USER MATHIASO3110 SET DEFAULT_SECONDARY_ROLES = ('ALL')"
  query   = "SHOW PARAMETERS LIKE 'DEFAULT_SECONDARY_ROLES' FOR USER MATHIASO3110"
}
