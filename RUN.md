# Running this

Every command runs from the repo root.

## Once

```bash
cp .env.example .env      # then fill in org/account/user
poetry install            # dbt-snowflake into a Python 3.11 venv
```

Register the public half of your key pair on the Snowflake user, so Terraform
and dbt can log in without a password (Snowflake blocks single-factor password
sign-in). In a Snowsight worksheet, as ACCOUNTADMIN:

```sql
ALTER USER <your_user> SET RSA_PUBLIC_KEY='<contents of ~/.snowflake/rsa_key.pub, minus the BEGIN/END lines>';
```

No key pair yet:

```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out ~/.snowflake/rsa_key.p8 -nocrypt
openssl rsa -in ~/.snowflake/rsa_key.p8 -pubout -out ~/.snowflake/rsa_key.pub
```

## Every shell

```bash
set -a; source .env; set +a
```

Loads credentials into the environment. Terraform, dbt and the load script all
read them from there — no secrets in any file in this repo.

## Build

```bash
cd terraform && terraform init && cd ..
```

Downloads the Snowflake provider into `terraform/.terraform/`. Needed once per
clone, and again whenever the provider version changes.

```bash
terraform -chdir=terraform plan     # what would change, changes nothing
terraform -chdir=terraform apply    # creates roles, warehouse, RAW + PROD
```

`plan` first, always: it is the only place you see a destructive change before
it happens. Look for `forces replacement` on anything holding data.

```bash
./scripts/load_raw.sh
```

Stands in for ingestion. Generates 36,000 synthetic meter readings, uploads
them, copies them into `RAW.METERING.METER_READINGS`. Rerunnable — it truncates
and reloads.

```bash
DBT_PROFILES_DIR=dbt poetry run dbt build --project-dir dbt
```

Builds the models and runs the tests. `build` rather than `run` + `test`, so a
model whose test fails does not silently feed the models below it.

## Look at it

```bash
snow sql -x -q "select * from PROD.ANALYTICS.FCT_CONSUMPTION_BY_AREA_DAILY limit 10" \
  --account "$SNOWFLAKE_ORGANIZATION_NAME-$SNOWFLAKE_ACCOUNT_NAME" \
  --user "$SNOWFLAKE_USER" --private-key-file ~/.snowflake/rsa_key.p8 \
  --authenticator SNOWFLAKE_JWT
```

Tired of the flags:

```bash
snow connection add --connection-name leap --default \
  --account "$SNOWFLAKE_ORGANIZATION_NAME-$SNOWFLAKE_ACCOUNT_NAME" \
  --user "$SNOWFLAKE_USER" --private-key-file ~/.snowflake/rsa_key.p8 \
  --authenticator SNOWFLAKE_JWT
```

Then `snow sql -q "..."` on its own.

## Tear down

```bash
terraform -chdir=terraform destroy
```

**This deletes the databases and everything inside them, including RAW.** It
will refuse: `RAW` and `RAW.METERING` carry `lifecycle { prevent_destroy = true }`,
which is the guard working as designed. To actually tear down, comment out the
two `lifecycle` blocks in `terraform/main.tf` first, then destroy — and put them
back afterwards.

Rebuild from nothing: `apply`, `./scripts/load_raw.sh`, `dbt build`. Takes about
a minute, which is the point — PROD is disposable by design.

Dropping just the dbt-built tables, leaving RAW and the infrastructure alone:

```bash
snow sql -q "drop schema if exists PROD.ANALYTICS cascade"
```

## Do not delete

`terraform/terraform.tfstate` is the map between the config and the real objects
in Snowflake. Delete it and Terraform forgets the twelve objects exist, then
tries to create them again and fails on name collisions. Recovering means
importing each one by hand. It is gitignored because it can contain secrets;
CI needs a remote backend before more than one person runs `apply`.
