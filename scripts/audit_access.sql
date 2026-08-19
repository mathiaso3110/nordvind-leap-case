// Who has actually read the CPR column, and which policies fired when they did.
// The other half of the auditor's question — demo_rbac.sql answers who *can*.
//
// ACCESS_HISTORY lags up to 3 hours and records successful queries only; a
// blocked attempt shows up in QUERY_HISTORY instead. Run both before claiming
// nobody touched something.

use role accountadmin;
use warehouse wh_transform;


// --- Every read of the CPR column -----------------------------------------

select
    ah.query_start_time,
    ah.user_name,
    obj.value:"objectName"::string   as object_name,
    col.value:"columnName"::string   as column_name
from snowflake.account_usage.access_history ah,
     lateral flatten(input => ah.base_objects_accessed)      obj,
     lateral flatten(input => obj.value:"columns")           col
where col.value:"columnName"::string = 'CPR'
order by ah.query_start_time desc
limit 50;


// --- Which policies were enforced, per query --------------------------------
// policies_referenced is the evidence that the control ran, not just that it
// exists. REGION_ACCESS and MASK_CPR both appear here.

// policies_referenced nests one level deeper than the other columns: an entry
// per object, each holding a policies array.
select
    ah.query_start_time,
    ah.user_name,
    ref.value:"objectName"::string   as object_name,
    pol.value:"policyKind"::string   as policy_kind,
    pol.value:"policyName"::string   as policy_name,
    pol.value:"columnName"::string   as column_name
from snowflake.account_usage.access_history ah,
     lateral flatten(input => ah.policies_referenced)  ref,
     lateral flatten(input => ref.value:"policies")    pol
order by ah.query_start_time desc
limit 50;


// --- Reads of the raw table, by user and role ------------------------------
// Joined to QUERY_HISTORY because ACCESS_HISTORY does not carry the role.

// Filter on the flattened rows rather than EXISTS — a correlated subquery over
// FLATTEN is not a supported subquery type in Snowflake.
select
    qh.role_name,
    ah.user_name,
    count(distinct ah.query_id) as queries,
    max(qh.start_time)          as last_read
from snowflake.account_usage.access_history ah
join snowflake.account_usage.query_history qh
  on qh.query_id = ah.query_id,
  lateral flatten(input => ah.base_objects_accessed) obj
where obj.value:"objectName"::string = 'RAW.PUBLIC.METER_READINGS'
group by 1, 2
order by queries desc;


// --- Attempts that were refused -------------------------------------------
// Denials never reach ACCESS_HISTORY. This is where FINANCE_ANALYST hitting the
// meter-level view shows up.

select
    role_name,
    count(*)          as denials,
    max(start_time)   as last_attempt
from snowflake.account_usage.query_history
where error_code = '002003'      // object does not exist or not authorized
group by 1
order by denials desc;

select
    start_time,
    user_name,
    role_name,
    left(query_text, 120) as query_text
from snowflake.account_usage.query_history
where error_code = '002003'
order by start_time desc
limit 20;
