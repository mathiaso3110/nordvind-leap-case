# Access roles hold object privileges; functional roles hold access roles. Adding
# a team means one line in access_to_functional, not a new grant chain.

locals {
  access_roles = {
    AR_RAW_READ         = "Read landed source data. Transformer only."
    AR_PROD_WRITE       = "Build models in PROD."
    AR_PROD_DETAIL_READ = "Read meter-level models."
    AR_PROD_AGG_READ    = "Read aggregate models."
    AR_PROD_SENSITIVE   = "See CPR unmasked. Separate from row access on purpose."
  }

  # Both read roles reach the same schema; what separates them is which models
  # dbt grants them SELECT on (see dbt_project.yml). Schema-level future grants
  # cannot tell a meter-level model from an aggregate one, so SELECT is dbt's job.
  prod_readers = ["AR_PROD_DETAIL_READ", "AR_PROD_AGG_READ"]

  access_to_functional = {
    AR_RAW_READ         = ["TRANSFORMER"]
    AR_PROD_WRITE       = ["TRANSFORMER"]
    AR_PROD_DETAIL_READ = ["GRID_OPS_DK1", "GRID_OPS_DK2", "DATA_SCIENCE_DK1", "DATA_SCIENCE_DK2"]
    AR_PROD_AGG_READ    = ["FINANCE_ANALYST", "GRID_OPS_DK1", "GRID_OPS_DK2", "DATA_SCIENCE_DK1", "DATA_SCIENCE_DK2"]

    # Grid Ops trace faults to a physical address, so they need the identity.
    # Data Science models consumption curves and never needs to know whose.
    # dbt must be exempt or it bakes '******-****' into PROD as data.
    AR_PROD_SENSITIVE = ["TRANSFORMER", "GRID_OPS_DK1", "GRID_OPS_DK2"]
  }

  role_pairs = merge([
    for access_role, functional_roles in local.access_to_functional : {
      for functional_role in functional_roles :
      "${access_role}|${functional_role}" => {
        access_role     = access_role
        functional_role = functional_role
      }
    }
  ]...)
}

resource "snowflake_account_role" "access" {
  for_each = local.access_roles

  name    = each.key
  comment = each.value
}

# --- RAW: transformer only -------------------------------------------------

resource "snowflake_grant_privileges_to_account_role" "raw_database" {
  account_role_name = snowflake_account_role.access["AR_RAW_READ"].name
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.raw.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "raw_schema" {
  account_role_name = snowflake_account_role.access["AR_RAW_READ"].name
  privileges        = ["USAGE"]

  on_schema {
    schema_name = "\"${snowflake_database.raw.name}\".\"PUBLIC\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "raw_tables" {
  account_role_name = snowflake_account_role.access["AR_RAW_READ"].name
  privileges        = ["SELECT"]

  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.raw.name}\".\"PUBLIC\""
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "raw_future_tables" {
  account_role_name = snowflake_account_role.access["AR_RAW_READ"].name
  privileges        = ["SELECT"]

  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_database        = snowflake_database.raw.name
    }
  }
}

# --- PROD: transformer writes, teams read ----------------------------------

resource "snowflake_grant_privileges_to_account_role" "prod_write" {
  account_role_name = snowflake_account_role.access["AR_PROD_WRITE"].name
  privileges        = ["USAGE", "CREATE SCHEMA"]

  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.prod.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "prod_schema_write" {
  account_role_name = snowflake_account_role.access["AR_PROD_WRITE"].name
  privileges        = ["USAGE", "CREATE TABLE", "CREATE VIEW"]

  on_schema {
    schema_name = snowflake_schema.prod_analytics.fully_qualified_name
  }
}

# Traversal only. SELECT comes per model from dbt, so a new mart is readable
# without a Terraform change and a new meter-level model is not readable by
# accident.
resource "snowflake_grant_privileges_to_account_role" "prod_database_usage" {
  for_each = toset(local.prod_readers)

  account_role_name = snowflake_account_role.access[each.key].name
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.prod.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "prod_schema_usage" {
  for_each = toset(local.prod_readers)

  account_role_name = snowflake_account_role.access[each.key].name
  privileges        = ["USAGE"]

  on_schema {
    schema_name = snowflake_schema.prod_analytics.fully_qualified_name
  }
}

# --- Access roles into functional roles ------------------------------------

resource "snowflake_grant_account_role" "access_to_functional" {
  for_each = local.role_pairs

  role_name        = snowflake_account_role.access[each.value.access_role].name
  parent_role_name = snowflake_account_role.functional[each.value.functional_role].name
}
