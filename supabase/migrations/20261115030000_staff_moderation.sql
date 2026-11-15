-- Restrict publication and verification to trusted staff.
create table public.staff_members (
 user_id uuid primary key references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
alter table public.staff_members enable row level security;
create policy "staff sees own membership" on public.staff_members for select to authenticated using(user_id=(select auth.uid()));
-- Staff membership must be inserted via Supabase SQL editor or service role only.

create table public.ownership_checks (
 property_id uuid primary key references public.properties(id) on delete cascade,
 owner_id uuid not null references auth.users(id) on delete cascade,
 declaration text not null check(length(trim(declaration)) between 20 and 2000),
 evidence_path text,
 status text not null default 'pending' check(status in ('pending','verified','rejected')),
 reviewer_id uuid references auth.users(id),
 reviewed_at timestamptz,
 created_at timestamptz not null default now()
);
alter table public.ownership_checks enable row level security;
create policy "owners read checks" on public.ownership_checks for select to authenticated using(owner_id=(select auth.uid()) or exists(select 1 from public.staff_members s where s.user_id=(select auth.uid())));
create policy "owners submit declaration" on public.ownership_checks for insert to authenticated with check(owner_id=(select auth.uid()) and status='pending' and reviewer_id is null and reviewed_at is null and exists(select 1 from public.properties p where p.id=property_id and p.owner_id=(select auth.uid())));

-- Existing owner UPDATE policy allows pending_review->draft. Prevent other transitions by trigger,
-- and enforce that only the trusted moderation RPC may publish or archive a published listing.
create or replace function public.enforce_property_status_transition()
returns trigger language plpgsql set search_path='' as $$
begin
 if new.status is distinct from old.status then
   if current_setting('homesquare.staff_moderation',true)='approved' then
     return new;
   end if;
   if old.owner_id=(select auth.uid()) and
     ((old.status='draft' and new.status='pending_review') or
      (old.status='pending_review' and new.status='draft') or
      (old.status='archived' and new.status='draft')) then
     return new;
   end if;
   raise exception 'Status transition requires staff moderation';
 end if;
 return new;
end $$;
create trigger protect_property_status before update on public.properties
 for each row execute function public.enforce_property_status_transition();

create or replace function public.staff_review_listing(p_property uuid,p_approve boolean,p_reason text default '')
returns void language plpgsql security definer set search_path='' as $$
declare v_owner uuid;
begin
 if not exists(select 1 from public.staff_members s where s.user_id=(select auth.uid())) then
   raise exception 'Staff access required';
 end if;
 select owner_id into v_owner from public.properties where id=p_property and status='pending_review' for update;
 if v_owner is null then raise exception 'Listing not pending review'; end if;
 if p_approve and not exists(select 1 from public.ownership_checks c where c.property_id=p_property and c.owner_id=v_owner and c.status='verified') then
   raise exception 'Ownership must be verified first';
 end if;
 perform set_config('homesquare.staff_moderation','approved',true);
 update public.properties set status=case when p_approve then 'published' else 'draft' end,updated_at=now() where id=p_property;
 perform set_config('homesquare.staff_moderation','',true);
 insert into public.listing_reviews(property_id,reviewer_id,decision,reason)
 values(p_property,(select auth.uid()),case when p_approve then 'approved' else 'rejected' end,coalesce(p_reason,''));
end $$;

create or replace function public.staff_review_ownership(p_property uuid,p_approve boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.staff_members s where s.user_id=(select auth.uid())) then raise exception 'Staff access required'; end if;
 update public.ownership_checks
 set status=case when p_approve then 'verified' else 'rejected' end,
 reviewer_id=(select auth.uid()),reviewed_at=now()
 where property_id=p_property and status='pending';
 if not found then raise exception 'No pending ownership check'; end if;
end $$;
revoke all on function public.staff_review_listing(uuid,boolean,text) from public;
revoke all on function public.staff_review_ownership(uuid,boolean) from public;
grant execute on function public.staff_review_listing(uuid,boolean,text) to authenticated;
grant execute on function public.staff_review_ownership(uuid,boolean) to authenticated;

create policy "staff sees pending listings" on public.properties for select to authenticated
 using(exists(select 1 from public.staff_members s where s.user_id=(select auth.uid())));
create policy "staff reads reviews" on public.listing_reviews for select to authenticated
 using(exists(select 1 from public.staff_members s where s.user_id=(select auth.uid())));
