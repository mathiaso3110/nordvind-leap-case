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
  # The provider ships table, stage and execute as preview resources. Named here
  # so it is obvious which parts of the config lean on unstable surface area.
  preview_features_enabled = [
    "snowflake_table_resource",
    "snowflake_stage_resource",
  ]
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

