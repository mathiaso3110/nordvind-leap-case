resource "snowflake_account_role" "transformer" {
  name    = "TRANSFORMER"
  comment = "Identity dbt runs as. Reads RAW, owns everything in PROD."
}

resource "snowflake_grant_privileges_to_account_role" "transformer_warehouse" {
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.transform.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_raw_database" {
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.raw.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_raw_schema" {
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE"]

  on_schema {
    schema_name = "\"${snowflake_database.raw.name}\".\"PUBLIC\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_raw_tables" {
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["SELECT"]

  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.raw.name}\".\"PUBLIC\""
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_raw_future_tables" {
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["SELECT"]

  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_database        = snowflake_database.raw.name
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_prod" {
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE", "CREATE SCHEMA"]

  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.prod.name
  }
}

resource "snowflake_grant_account_role" "transformer_to_dbt_user" {
  role_name = snowflake_account_role.transformer.name
  user_name = "MATHIASO3110"
}