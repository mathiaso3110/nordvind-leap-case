// RBAC, row access and column masking demo.
//
// Top block: pick an identity. Bottom block: run the same queries and watch the
// answers change. Nothing below cares which role you picked.
//
// Depends on DEFAULT_SECONDARY_ROLES = () on the user. With Snowflake's default
// of ALL every granted role stays active, USE ROLE isolates nothing, and every
// query below silently passes.

select current_role(), current_secondary_roles();   // secondary "roles" must be empty


// ===========================================================================
// 1. IDENTITIES — run one pair, then jump to section 2
// ===========================================================================

use role accountadmin;      use warehouse wh_transform;     // owns the account
use role transformer;       use warehouse wh_transform;     // what dbt runs as
use role finance_analyst;   use warehouse wh_finance;       // aggregates only
use role grid_ops_dk1;      use warehouse wh_grid;          // DK1 + identity
use role grid_ops_dk2;      use warehouse wh_grid;          // DK2 + identity
use role data_science_dk1;  use warehouse wh_datascience;   // DK1, no identity
use role data_science_dk2;  use warehouse wh_datascience;   // DK2, no identity


// ===========================================================================
// 2. QUERIES — identical for every role
// ===========================================================================

// --- Landed source data ----------------------------------------------------
// accountadmin      36000, CPR masked
// transformer       36000, CPR cleartext
// everyone else     not authorized — RAW is transformer-only
select count(*) from RAW.PUBLIC.METER_READINGS;

select meter_id, cpr, region from RAW.PUBLIC.METER_READINGS limit 5;


// --- Meter-level model -----------------------------------------------------
// accountadmin      36000     transformer   36000
// grid_ops_dk1      17280     grid_ops_dk2  18720
// data_science_dk1  17280     data_science_dk2  18720
// finance_analyst   not authorized
//
// 17280 + 18720 = 36000. Neither area can tell the other exists.
select count(*) from PROD.ANALYTICS.METER_READINGS;

// Same aggregation, different answer per role. No WHERE clause anywhere.
select region, count(*) as readings
from PROD.ANALYTICS.METER_READINGS
group by region;


// --- Who is behind the meter ----------------------------------------------
// transformer, grid_ops_dk1, grid_ops_dk2    CPR cleartext
// accountadmin, data_science_dk1/dk2         ******-****
//
// Grid Ops traces a fault to a physical address, so it needs the identity.
// Data Science models consumption curves and never needs to know whose.
// dbt is exempt or it would write '******-****' into PROD as real data.
// ACCOUNTADMIN is not exempt: owning the account is not a reason to read CPR.
select meter_id, cpr, region
from PROD.ANALYTICS.METER_READINGS limit 5;


// --- Aggregate mart --------------------------------------------------------
// every role above    180 rows, no meter, no CPR
//
// The cheapest access control is not propagating the data. This model needs no
// policy at all.
select * from PROD.ANALYTICS.CONSUMPTION_BY_AREA_DAILY limit 10;


// ===========================================================================
// 3. WHAT THE AUDITOR ASKS — who *can* see it
// ===========================================================================

use role accountadmin;

show grants on table RAW.PUBLIC.METER_READINGS;     // AR_RAW_READ and the owner, nothing else
show grants to role finance_analyst;                // one access role, one warehouse
show grants of role AR_PROD_SENSITIVE;              // who can read CPR: OF, not TO

select policy_name, policy_kind, ref_column_name
from table(GOVERNANCE.information_schema.policy_references(
  ref_entity_name   => 'RAW.PUBLIC.METER_READINGS',
  ref_entity_domain => 'TABLE'));                   // REGION_ACCESS + MASK_CPR on CPR

// Still missing: who *has* seen it. That is ACCOUNT_USAGE.ACCESS_HISTORY, which
// needs hours of latency before it has anything to show.
