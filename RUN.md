# Running this

Every command runs from the repo root.

## Build

Terraform runs from `terraform/`:

```bash
cd terraform
terraform init      # downloads the Snowflake provider, once per clone
terraform plan      # what would change, changes nothing
terraform apply     # creates roles, warehouse, RAW + PROD
cd ..
```

`plan` first, always: it is the only place you see a destructive change before
it happens. Look for `forces replacement` on anything holding data.

Then, once, as `ACCOUNTADMIN`:

```sql
grant select on all tables in schema RAW.PUBLIC to role AR_RAW_READ;
```

Terraform's `ALL TABLES` grant is a snapshot taken at apply time, and nothing
ties it to `METER_READINGS`, so it can run before the table exists. The
`FUTURE TABLES` grant only covers tables created after it. The table lands
between the two and `TRANSFORMER` gets no `SELECT` — dbt then fails with
`Object 'RAW.PUBLIC.METER_READINGS' does not exist or not authorized`. This
line closes the gap by hand; rerun it after any `destroy` + `apply`.

The rest runs from the repo root:

```bash
./scripts/load_raw.sh
```

Stands in for ingestion. Generates 36,000 synthetic meter readings, uploads
them, copies them into `RAW.PUBLIC.METER_READINGS`. Rerunnable - it truncates
and reloads.

```bash
DBT_PROFILES_DIR=dbt poetry run dbt build --project-dir dbt
```

## Tear down

```bash
cd terraform && terraform destroy
```
