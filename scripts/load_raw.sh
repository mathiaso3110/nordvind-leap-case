#!/usr/bin/env bash
# Stand-in for ingestion: generate readings and land them in RAW.
# Production would be Snowpipe auto-ingesting from Azure Blob; the table below
# would be created by the ingestion pipeline, not by this script.
#
# Usage:  set -a; source .env; set +a;  ./scripts/load_raw.sh
set -euo pipefail

cd "$(dirname "$0")/.."

SNOW=(snow sql -x
  --account "${SNOWFLAKE_ORGANIZATION_NAME}-${SNOWFLAKE_ACCOUNT_NAME}"
  --user "${SNOWFLAKE_USER}"
  --private-key-file "${HOME}/.snowflake/rsa_key.p8"
  --authenticator SNOWFLAKE_JWT)

CSV=$(mktemp --suffix=.csv)
trap 'rm -f "$CSV"' EXIT
python3 scripts/generate_meter_data.py > "$CSV"

"${SNOW[@]}" -q "
create table if not exists RAW.METERING.METER_READINGS (
  meter_id    string,
  customer_id string,
  grid_area   string,
  read_at     timestamp_ntz,
  kwh         number(10,3)
);
create stage if not exists RAW.METERING.LANDING;
"

snow stage copy "$CSV" @RAW.METERING.LANDING -x \
  --account "${SNOWFLAKE_ORGANIZATION_NAME}-${SNOWFLAKE_ACCOUNT_NAME}" \
  --user "${SNOWFLAKE_USER}" \
  --private-key-file "${HOME}/.snowflake/rsa_key.p8" \
  --authenticator SNOWFLAKE_JWT

# truncate + reload: this is a demo source, not an incremental pipeline yet.
"${SNOW[@]}" -q "
truncate table RAW.METERING.METER_READINGS;
copy into RAW.METERING.METER_READINGS
  from @RAW.METERING.LANDING/$(basename "$CSV")
  force = true
  file_format = (type = csv skip_header = 1 field_optionally_enclosed_by = '\"');
select count(*) as rows_loaded from RAW.METERING.METER_READINGS;
"
