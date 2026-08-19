# Team roles. The DK1/DK2 split exists so a row access policy can key off
# CURRENT_ROLE() instead of a mapping table lookup.

resource "snowflake_account_role" "team" {
  for_each = {
    FINANCE          = "Regulatory reporting."
    DATA_SCIENCE_DK1 = "Data Science, price area DK1."
    DATA_SCIENCE_DK2 = "Data Science, price area DK2."
    GRID_OPS_DK1     = "Grid Operations, price area DK1."
    GRID_OPS_DK2     = "Grid Operations, price area DK2."
  }

  name    = each.key
  comment = each.value
}
