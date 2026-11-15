-- In-app activity feed backed by participant-visible records.
-- SECURITY INVOKER ensures underlying table RLS is enforced.
create or replace view public.my_activity with (security_invoker=true) as
select 'inspection'::text as kind,i.id,i.buyer_id as user_id,i.property_id,i.status as detail,i.created_at
from public.inspections i
union all
select 'offer',o.id,o.buyer_id,o.property_id,o.status,o.created_at from public.offers o
union all
select 'message',m.id,m.buyer_id,m.property_id,'new message',m.created_at from public.messages m;
grant select on public.my_activity to authenticated;
-- Client queries must still filter user_id = auth.uid() and apply table RLS.
