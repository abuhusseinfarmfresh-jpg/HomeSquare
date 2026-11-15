-- HomeSquare SECURITY AUDIT (read-only).
-- Run in Supabase SQL Editor against the actual deployed database.
-- Review every returned row; no results are modified.
-- Check policies for each table used by the browser client.
select t.table_name,
       t.row_security as rls_enabled,
       coalesce(string_agg(distinct p.policyname || ' [' || p.cmd || ']', ', ' order by p.policyname || ' [' || p.cmd || ']'), '(no policies)') as policies
from (
 select c.relname as table_name,c.relrowsecurity as row_security
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relkind='r'
 and c.relname in ('profiles','properties','enquiries','offers','inspections','messages',
                   'property_photos','ownership_checks','staff_members','service_requests')
) t left join pg_policies p on p.schemaname='public' and p.tablename=t.table_name
group by t.table_name,t.row_security order by t.table_name;

-- Inspect exposed RPC permissions and whether functions run with definer rights.
select n.nspname as schema_name,p.proname as function_name,
       p.prosecdef as security_definer,
       pg_get_function_arguments(p.oid) as arguments,
       array_to_string(p.proacl,', ') as explicit_acl
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
and p.proname in ('staff_review_listing','staff_review_ownership','staff_update_service',
                 'seller_decide_offer','seller_decide_inspection','homesquare_guard_property_changes')
order by p.proname;

-- Inspect storage bucket visibility; ownership evidence must be private.
select id,public,file_size_limit,allowed_mime_types from storage.buckets
where id in ('property-photos','ownership-evidence');

-- Inspect all storage object policies; ensure writes are restricted by property ownership,
-- and private ownership evidence can be read only by its owner or authorised staff.
select policyname,cmd,roles,qual,with_check from pg_policies
where schemaname='storage' and tablename='objects'
order by policyname;

-- Manual negative tests required before launch:
-- anonymous: published listings only; no private messages, offers, evidence or drafts.
-- buyer A: cannot read buyer B's messages, offers, inspection requests or enquiries.
-- seller A: cannot modify seller B's listing, photos or ownership evidence.
-- seller: cannot publish, approve ownership, or invoke staff RPCs.
-- staff: can moderate only after server-side staff membership verification.
-- account owner: can delete own draft, not a published or in-review listing.
