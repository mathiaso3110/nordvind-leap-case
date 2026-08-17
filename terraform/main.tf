terraform {
  required_version = ">= 1.5"

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.19"
    }
  }
}

# Credentials come from SNOWFLAKE_* environment variables — see .env.example.
provider "snowflake" {}

variable "dbt_user" {
  description = "Snowflake user that dbt runs as. Human user for now; a key-pair service user in production."
  type        = string
}
