terraform {
  required_version = ">= 1.5"

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.19"
    }
  }
}

provider "snowflake" {
  # snowflake_table is still a preview resource. Named here so it is obvious
  # which part of the config leans on unstable surface area.
  preview_features_enabled = ["snowflake_table_resource", "snowflake_table_column_masking_policy_application_resource"]
}

# --- Databases -------------------------------------------------------------

resource "snowflake_database" "raw" {
  name                        = "RAW"
  comment                     = "Landed source data. Written by ingestion only; dbt reads via source()."
  data_retention_time_in_days = 7

  lifecycle {
    prevent_destroy = false # Set to true
  }
}

resource "snowflake_database" "prod" {
  name    = "PROD"
  comment = "dbt-built tables. Fully reproducible from RAW + Git."
}

# dbt would create this itself, but then Terraform could not grant on it:
# schema-level USAGE needs the schema to already exist.
resource "snowflake_schema" "prod_analytics" {
  database = snowflake_database.prod.name
  name     = "ANALYTICS"
  comment  = "Everything dbt builds."
}

