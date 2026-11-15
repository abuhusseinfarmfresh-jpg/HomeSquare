-- HomeSquare additional ownership-check hardening.
-- Apply after all 20261115 migrations and security-property-review.sql.
begin;
create or replace function public.protect_ownership_review()
returns trigger language plpgsql set search_path='' as $$
begin
 if new.owner_id is distinct from old.owner_id or new.property_id is distinct from old.property_id then
   raise exception 'Ownership check identity cannot be changed';
 end if;
 if (new.status,new.reviewer_id,new.reviewed_at) is distinct from
    (old.status,old.reviewer_id,old.reviewed_at) then
   if current_user <> 'postgres' or auth.uid() is null or
      not exists(select 1 from public.staff_members s where s.user_id=auth.uid()) then
     raise exception 'Only trusted staff moderation can change ownership review outcomes';
   end if;
 end if;
 if new.evidence_path is distinct from old.evidence_path then
   if old.status <> 'pending' or new.evidence_path is null or
      left(new.evidence_path,length(new.property_id::text)+1) <> new.property_id::text || '/' or
      not exists(select 1 from storage.objects o
        where o.bucket_id='ownership-evidence' and o.name=new.evidence_path) then
     raise exception 'Evidence must be an uploaded file under this property';
   end if;
 end if;
 return new;
end $$;
-- Existing protect_ownership_check trigger invokes this replaced function.
-- Prevent profile updates from changing account role (role is not staff access).
create or replace function public.homesquare_guard_profile_role()
returns trigger language plpgsql set search_path='' as $$
begin
 if new.id is distinct from old.id or new.role is distinct from old.role then
   raise exception 'Profile identity and role cannot be changed by client';
 end if;
 return new;
end $$;
drop trigger if exists homesquare_guard_profile_role on public.profiles;
create trigger homesquare_guard_profile_role before update on public.profiles
for each row execute function public.homesquare_guard_profile_role();
commit;
