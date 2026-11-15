-- HomeSquare: restrict property changes even when an RLS policy is accidentally broad.
-- Apply in the Supabase SQL editor after schema.sql. Review against deployed schema first.
-- Staff moderation must use a trusted server-side service-role operation or reviewed RPC.
begin;
create or replace function public.homesquare_guard_property_changes()
returns trigger language plpgsql set search_path = '' as $$
begin
  -- Trusted service-role moderation can publish/archive. Never put its key in the browser.
  if auth.role() = 'service_role' then return new; end if;
  -- Staff RPCs run as database-owner SECURITY DEFINER functions.
  -- Permit only staff-authenticated review of pending listings, with no field edits.
  if current_user = 'postgres'
     and auth.uid() is not null
     and exists(select 1 from public.staff_members sm where sm.user_id=auth.uid())
     and old.status = 'pending_review'
     and new.status in ('published','draft')
     and new.id is not distinct from old.id
     and new.owner_id is not distinct from old.owner_id
     and (new.address,new.suburb,new.state,new.property_type,new.price,new.beds,new.baths,new.description,new.postcode)
         is not distinct from
         (old.address,old.suburb,old.state,old.property_type,old.price,old.beds,old.baths,old.description,old.postcode)
  then return new; end if;
  if auth.uid() is null or old.owner_id is distinct from auth.uid() then
    raise exception 'Only the listing owner may edit this property';
  end if;
  if new.id is distinct from old.id or new.owner_id is distinct from old.owner_id then
    raise exception 'Listing identity and owner cannot be changed';
  end if;
  if old.status <> 'draft' then
    raise exception 'Only draft listings may be edited by their owners';
  end if;
  if new.status not in ('draft','pending_review') then
    raise exception 'Owners cannot publish or archive their own listings';
  end if;
  if new.status = 'pending_review' and (
    new.address is distinct from old.address or
    new.suburb is distinct from old.suburb or
    new.state is distinct from old.state or
    new.property_type is distinct from old.property_type or
    new.price is distinct from old.price or
    new.beds is distinct from old.beds or
    new.baths is distinct from old.baths or
    new.description is distinct from old.description or
    new.postcode is distinct from old.postcode
  ) then
    raise exception 'Save draft changes before submitting for review';
  end if;
  return new;
end;
$$;
drop trigger if exists homesquare_guard_property_changes on public.properties;
create trigger homesquare_guard_property_changes
before update on public.properties
for each row execute function public.homesquare_guard_property_changes();

-- Replace broad owner update policy with one allowing draft edits and review submission.
drop policy if exists "Owners edit own nonpublished listings" on public.properties;
create policy "Owners edit drafts or submit for review"
on public.properties for update to authenticated
using (owner_id = (select auth.uid()) and status = 'draft')
with check (owner_id = (select auth.uid()) and status in ('draft','pending_review'));
commit;
