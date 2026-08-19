# Terraform owns the landing table's structure, not its contents. Snowpipe needs
# its target table to exist before it can COPY into it, so in production this is
# IaC's job too — and it lets the row access policy be attached here rather than
# from a script.

resource "snowflake_table" "meter_readings" {
  database = snowflake_database.raw.name
  schema   = "PUBLIC"
  name     = "METER_READINGS"
  comment  = "Hourly smart meter readings. CPR column is personal data."

  column {
    name = "METER_ID"
    type = "VARCHAR"
  }

  column {
    name = "CPR"
    type = "VARCHAR"
  }

  column {
    name = "REGION"
    type = "VARCHAR"
  }

  column {
    name = "SUBREGION"
    type = "VARCHAR"
  }

  column {
    name = "READ_AT"
    type = "TIMESTAMP_NTZ(9)"
  }

  column {
    name = "KWH"
    type = "NUMBER(10,3)"
  }
}

# No provider resource attaches a row access policy to a table, so this is the
# escape hatch. revert runs on destroy, which is why the policy can be dropped
# cleanly.
resource "snowflake_execute" "attach_region_policy" {
  execute = "ALTER TABLE ${snowflake_table.meter_readings.fully_qualified_name} ADD ROW ACCESS POLICY ${snowflake_row_access_policy.region_access.fully_qualified_name} ON (REGION)"
  revert  = "ALTER TABLE ${snowflake_table.meter_readings.fully_qualified_name} DROP ROW ACCESS POLICY ${snowflake_row_access_policy.region_access.fully_qualified_name}"
}
