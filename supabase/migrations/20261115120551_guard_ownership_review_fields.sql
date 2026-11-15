create or replace function public.homesquare_guard_ownership_check()
returns trigger language plpgsql set search_path='' as $$
begin
 if new.property_id is distinct from old.property_id or new.owner_id is distinct from old.owner_id
    or new.created_at is distinct from old.created_at then
   raise exception 'Ownership check identity is immutable';
 end if;
 if (new.status,new.reviewer_id,new.reviewed_at) is distinct from (old.status,old.reviewer_id,old.reviewed_at) then
   if not (current_user='postgres' and auth.uid() is not null
       and exists(select 1 from public.staff_members s where s.user_id=auth.uid())
       and old.status='pending' and new.status in ('verified','rejected')
       and new.reviewer_id=auth.uid() and new.reviewed_at is not null
       and new.evidence_path is not distinct from old.evidence_path
       and new.declaration is not distinct from old.declaration) then
     raise exception 'Only staff may review pending ownership checks';
   end if;
 end if;
 if new.evidence_path is distinct from old.evidence_path then
   if old.status<>'pending' or new.status<>'pending'
      or new.evidence_path is null
      or left(new.evidence_path,length(new.property_id::text)+1)<>new.property_id::text||'/'
      or not exists(select 1 from storage.objects o where o.bucket_id='ownership-evidence' and o.name=new.evidence_path) then
     raise exception 'Ownership evidence must be an uploaded file for this property';
   end if;
 end if;
 return new;
end $$;
drop trigger if exists homesquare_guard_ownership_check on public.ownership_checks;
create trigger homesquare_guard_ownership_check before update on public.ownership_checks
for each row execute function public.homesquare_guard_ownership_check();
