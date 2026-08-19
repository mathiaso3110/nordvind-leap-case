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
