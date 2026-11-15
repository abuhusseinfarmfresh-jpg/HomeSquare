drop policy if exists "Owners edit own nonpublished listings" on public.properties;
drop policy if exists "Owners edit drafts or submit for review" on public.properties;
create policy "Owners edit drafts or submit for review" on public.properties
for update to authenticated
using (owner_id=auth.uid() and status='draft')
with check (owner_id=auth.uid() and status in ('draft','pending_review'));
create or replace function public.homesquare_guard_property_update()
returns trigger language plpgsql set search_path='' as $$
begin
 if new.id is distinct from old.id or new.owner_id is distinct from old.owner_id or new.created_at is distinct from old.created_at then
   raise exception 'Listing identity cannot be changed';
 end if;
 if current_user='postgres' and auth.uid() is not null
   and exists(select 1 from public.staff_members s where s.user_id=auth.uid())
   and old.status='pending_review' and new.status in ('published','draft')
   and (to_jsonb(new)-'status'-'updated_at') is not distinct from (to_jsonb(old)-'status'-'updated_at')
 then return new; end if;
 if auth.uid()=old.owner_id and old.status='draft' and new.status in ('draft','pending_review') then
   if new.status='pending_review' and
      (to_jsonb(new)-'status'-'updated_at') is distinct from (to_jsonb(old)-'status'-'updated_at') then
     raise exception 'Submit for review separately from editing listing details';
   end if;
   return new;
 end if;
 raise exception 'Listing cannot be modified in this status';
end $$;
drop trigger if exists homesquare_guard_property_update on public.properties;
create trigger homesquare_guard_property_update before update on public.properties for each row execute function public.homesquare_guard_property_update();
