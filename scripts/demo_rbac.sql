// RBAC + row access policy demo. Run one statement at a time in Snowsight.
// Expected results are in the comments — if they differ, something drifted.
//
// Works because DEFAULT_SECONDARY_ROLES is () on the user. With Snowflake's
// default of ALL, every granted role stays active and USE ROLE proves nothing.

select current_role(), current_secondary_roles();   // secondary "roles" must be empty


// ---------------------------------------------------------------------------
// Platform admin: every row, and still no CPR
// ---------------------------------------------------------------------------

use role accountadmin;
use warehouse wh_transform;

select count(*) from RAW.PUBLIC.METER_READINGS;     // 36000 — all rows, all areas
select meter_id, cpr, region
from RAW.PUBLIC.METER_READINGS limit 10;            // CPR masked: ******-****

// Owning the account is not a reason to read personal data. ACCOUNTADMIN does not
// hold AR_PROD_SENSITIVE, so the masking policy applies to it like anyone else.


// ---------------------------------------------------------------------------
// Transformer: what dbt runs as. Reads RAW, builds PROD, owns neither team's data
// ---------------------------------------------------------------------------

use role transformer;
use warehouse wh_transform;

select count(*) from RAW.PUBLIC.METER_READINGS;     // 36000 — policy allows it through
select meter_id, cpr from RAW.PUBLIC.METER_READINGS limit 5;  // CPR in cleartext

// dbt must see unmasked values, or it writes '******-****' into PROD as real data.
// That is why TRANSFORMER holds AR_PROD_SENSITIVE.


// ---------------------------------------------------------------------------
// Finance: aggregates only. No meter, no CPR, no row-level anything
// ---------------------------------------------------------------------------

use role finance_analyst;
use warehouse wh_finance;

select * from PROD.ANALYTICS.CONSUMPTION_BY_AREA_DAILY limit 10;   // works, 180 rows total

select count(*) from RAW.PUBLIC.METER_READINGS;          // FAILS: not authorized
select count(*) from PROD.ANALYTICS.METER_READINGS;  // FAILS: not authorized

// Blocked at the privilege layer, before any policy runs. The cheapest access
// control is not propagating the data in the first place.


// ---------------------------------------------------------------------------
// Grid Operations DK1: meter-level, west of the Great Belt only
// ---------------------------------------------------------------------------

use role grid_ops_dk1;
use warehouse wh_grid;

select count(*) from PROD.ANALYTICS.METER_READINGS;  // 17280 — not 36000

select region, count(*)
from PROD.ANALYTICS.METER_READINGS
group by region;                                    // DK1 only — DK2 is invisible, not empty

select count(*) from RAW.PUBLIC.METER_READINGS;     // FAILS: RAW is transformer-only


// ---------------------------------------------------------------------------
// Grid Operations DK2: same query, different answer
// ---------------------------------------------------------------------------

use role grid_ops_dk2;
use warehouse wh_grid;

select region, count(*)
from PROD.ANALYTICS.METER_READINGS
group by region;                                    // DK2 only, 18720 rows

// 17280 + 18720 = 36000. Neither role can tell the other half exists.


// ---------------------------------------------------------------------------
// Data Science DK1 / DK2: same policy, different team
// ---------------------------------------------------------------------------

use role data_science_dk1;
use warehouse wh_datascience;

select region, count(*)
from PROD.ANALYTICS.METER_READINGS
group by region;                                    // DK1, 17280

use role data_science_dk2;

select region, count(*)
from PROD.ANALYTICS.METER_READINGS
group by region;                                    // DK2, 18720

// The policy keys off CURRENT_ROLE(), so one rule covers four roles and two teams.
// No mapping table, no per-row join.


// ---------------------------------------------------------------------------
// Column masking: which rows and which columns are separate questions
// ---------------------------------------------------------------------------

use role grid_ops_dk1;
use warehouse wh_grid;

select meter_id, cpr, region
from PROD.ANALYTICS.METER_READINGS limit 5;      // CPR readable — traces faults to an address

use role data_science_dk1;
use warehouse wh_datascience;

select meter_id, cpr, region
from PROD.ANALYTICS.METER_READINGS limit 5;      // ******-**** — same rows, no identity

// Both roles see DK1 rows; only Grid Ops sees who. Row access and column masking
// are deliberately independent: one line in access_to_functional moves the second
// without touching the first.
//
// The policy sits on the RAW column. The dbt view inherits it with no config of
// its own — masking follows the column through views.


// ---------------------------------------------------------------------------
// Who can see what — the question the auditor actually asks
// ---------------------------------------------------------------------------

use role accountadmin;

show grants on table RAW.PUBLIC.METER_READINGS;     // AR_RAW_READ + owner, nothing else
show grants to role finance_analyst;                // one access role, one warehouse

select *
from table(GOVERNANCE.information_schema.policy_references(
  ref_entity_name   => 'RAW.PUBLIC.METER_READINGS',
  ref_entity_domain => 'TABLE'));                   // REGION_ACCESS + MASK_CPR, and which column

show grants to role AR_PROD_SENSITIVE;              // who can see CPR: one query, one answer
