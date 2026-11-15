-- Seller decisions with server-enforced transitions; buyers cannot decide their own offers.
create or replace function public.seller_decide_inspection(p_id uuid,p_decision text)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if p_decision not in ('confirmed','declined') then raise exception 'Invalid decision'; end if;
 update public.inspections i set status=p_decision
 where i.id=p_id and i.status='requested'
 and exists(select 1 from public.properties p where p.id=i.property_id and p.owner_id=(select auth.uid()));
 if not found then raise exception 'Inspection unavailable or not authorised'; end if;
end $$;
create or replace function public.seller_decide_offer(p_id uuid,p_decision text)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if p_decision not in ('accepted','declined') then raise exception 'Invalid decision'; end if;
 update public.offers o set status=p_decision
 where o.id=p_id and o.status='submitted'
 and exists(select 1 from public.properties p where p.id=o.property_id and p.owner_id=(select auth.uid()));
 if not found then raise exception 'Offer unavailable or not authorised'; end if;
end $$;
revoke all on function public.seller_decide_inspection(uuid,text) from public;
revoke all on function public.seller_decide_offer(uuid,text) from public;
grant execute on function public.seller_decide_inspection(uuid,text) to authenticated;
grant execute on function public.seller_decide_offer(uuid,text) to authenticated;

-- Prevent seller-controlled modifications of decisions by direct table writes.
-- Admin moderation must be carried out through a trusted server-side role.
create table public.listing_reviews (
 id uuid primary key default gen_random_uuid(),
 property_id uuid not null references public.properties(id) on delete cascade,
 reviewer_id uuid not null references auth.users(id),
 decision text not null check(decision in ('approved','rejected')),
 reason text not null default '',
 created_at timestamptz not null default now()
);
alter table public.listing_reviews enable row level security;
create policy "owner reads review outcome" on public.listing_reviews for select to authenticated
 using(exists(select 1 from public.properties p where p.id=property_id and p.owner_id=(select auth.uid())));
-- No client INSERT/UPDATE/DELETE policy. Only trusted service-side moderation.
create index if not exists listing_reviews_property_idx on public.listing_reviews(property_id,created_at desc);
