-- Private ownership evidence uploads, readable only by owner and approved staff.
alter table public.ownership_checks add column if not exists evidence_path text;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('ownership-evidence','ownership-evidence',false,10485760,array['application/pdf','image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
create policy "owner uploads evidence" on storage.objects for insert to authenticated
with check(bucket_id='ownership-evidence' and exists(
 select 1 from public.properties p where p.id::text=split_part(name,'/',1)
 and p.owner_id=(select auth.uid()) and p.status in ('draft','pending_review')
));
create policy "owner and staff read evidence" on storage.objects for select to authenticated
using(bucket_id='ownership-evidence' and (
 exists(select 1 from public.properties p where p.id::text=split_part(name,'/',1) and p.owner_id=(select auth.uid()))
 or exists(select 1 from public.staff_members s where s.user_id=(select auth.uid()))
));
create policy "owner updates own pending declaration" on public.ownership_checks for update to authenticated
using(owner_id=(select auth.uid()) and status='pending')
with check(owner_id=(select auth.uid()) and status='pending' and reviewer_id is null and reviewed_at is null);
-- The staff review RPC must use service-side vetting of evidence, not declarations alone.

-- Block users from marking their own declaration as verified via direct UPDATE.
create or replace function public.protect_ownership_review()
returns trigger language plpgsql set search_path='' as $$
begin
 if (new.status,new.reviewer_id,new.reviewed_at) is distinct from
    (old.status,old.reviewer_id,old.reviewed_at) then
   if not exists(select 1 from public.staff_members s where s.user_id=(select auth.uid())) then
     raise exception 'Only staff can change ownership review outcomes';
   end if;
 end if;
 if new.owner_id is distinct from old.owner_id or new.property_id is distinct from old.property_id then
   raise exception 'Ownership check identity cannot be changed';
 end if;
 return new;
end $$;
create trigger protect_ownership_check before update on public.ownership_checks
for each row execute function public.protect_ownership_review();

-- Require supporting evidence before staff may approve a declaration.
create or replace function public.staff_review_ownership(p_property uuid,p_approve boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.staff_members s where s.user_id=(select auth.uid())) then raise exception 'Staff access required'; end if;
 if p_approve and not exists(select 1 from public.ownership_checks c where c.property_id=p_property and c.status='pending' and c.evidence_path is not null and exists(select 1 from storage.objects o where o.bucket_id='ownership-evidence' and o.name=c.evidence_path)) then
  raise exception 'Supporting ownership evidence must be uploaded before approval';
 end if;
 update public.ownership_checks set status=case when p_approve then 'verified' else 'rejected' end,reviewer_id=(select auth.uid()),reviewed_at=now()
 where property_id=p_property and status='pending';
 if not found then raise exception 'No pending ownership check'; end if;
end $$;
