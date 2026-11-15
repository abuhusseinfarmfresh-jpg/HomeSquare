-- HomeSquare non-payment marketplace features.
-- Moderation is performed only by trusted server-side staff tooling.
create table public.inspections (
 id uuid primary key default gen_random_uuid(),
 property_id uuid not null references public.properties(id) on delete cascade,
 buyer_id uuid not null references auth.users(id) on delete cascade,
 requested_at timestamptz not null,
 message text not null default '',
 status text not null default 'requested' check(status in ('requested','confirmed','declined','cancelled')),
 created_at timestamptz not null default now()
);
create table public.offers (
 id uuid primary key default gen_random_uuid(),
 property_id uuid not null references public.properties(id) on delete cascade,
 buyer_id uuid not null references auth.users(id) on delete cascade,
 amount numeric(14,2) not null check(amount>0),
 message text not null default '',
 status text not null default 'submitted' check(status in ('submitted','accepted','declined','withdrawn')),
 created_at timestamptz not null default now()
);
create table public.messages (
 id uuid primary key default gen_random_uuid(),
 property_id uuid not null references public.properties(id) on delete cascade,
 buyer_id uuid not null references auth.users(id) on delete cascade,
 sender_id uuid not null references auth.users(id) on delete cascade,
 body text not null check(length(trim(body)) between 1 and 5000),
 created_at timestamptz not null default now()
);
create table public.property_photos (
 id uuid primary key default gen_random_uuid(),
 property_id uuid not null references public.properties(id) on delete cascade,
 storage_path text not null unique,
 created_at timestamptz not null default now()
);
create table public.service_requests (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 property_id uuid references public.properties(id) on delete set null,
 service text not null check(service in ('photography','signboard')),
 details text not null default '',
 status text not null default 'requested' check(status in ('requested','contacted','scheduled','completed','cancelled')),
 created_at timestamptz not null default now()
);
create index inspections_property_idx on public.inspections(property_id,created_at desc);
create index offers_property_idx on public.offers(property_id,created_at desc);
create index messages_thread_idx on public.messages(property_id,buyer_id,created_at);
create index photos_property_idx on public.property_photos(property_id);
alter table public.inspections enable row level security;
alter table public.offers enable row level security;
alter table public.messages enable row level security;
alter table public.property_photos enable row level security;
alter table public.service_requests enable row level security;
create policy "inspection participants read" on public.inspections for select to authenticated using(buyer_id=auth.uid() or exists(select 1 from public.properties p where p.id=property_id and p.owner_id=auth.uid()));
create policy "buyer requests inspection" on public.inspections for insert to authenticated with check(buyer_id=auth.uid() and requested_at>now() and exists(select 1 from public.properties p where p.id=property_id and p.status='published' and p.owner_id<>auth.uid()));
create policy "buyer cancels inspection" on public.inspections for update to authenticated using(buyer_id=auth.uid() and status='requested') with check(buyer_id=auth.uid() and status='cancelled');
create policy "offers participants read" on public.offers for select to authenticated using(buyer_id=auth.uid() or exists(select 1 from public.properties p where p.id=property_id and p.owner_id=auth.uid()));
create policy "buyer submits offer" on public.offers for insert to authenticated with check(buyer_id=auth.uid() and status='submitted' and exists(select 1 from public.properties p where p.id=property_id and p.status='published' and p.owner_id<>auth.uid()));
create policy "buyer withdraws offer" on public.offers for update to authenticated using(buyer_id=auth.uid() and status='submitted') with check(buyer_id=auth.uid() and status='withdrawn');
create policy "thread participants read" on public.messages for select to authenticated using(buyer_id=auth.uid() or exists(select 1 from public.properties p where p.id=property_id and p.owner_id=auth.uid()));
create policy "thread participants send" on public.messages for insert to authenticated with check(
 (sender_id=auth.uid() and buyer_id=auth.uid() and exists(select 1 from public.properties p where p.id=property_id and p.status='published' and p.owner_id<>auth.uid()))
 or (sender_id=auth.uid() and exists(select 1 from public.properties p where p.id=property_id and p.owner_id=auth.uid()) and (exists(select 1 from public.enquiries e where e.property_id=messages.property_id and e.buyer_id=messages.buyer_id) or exists(select 1 from public.inspections i where i.property_id=messages.property_id and i.buyer_id=messages.buyer_id) or exists(select 1 from public.offers o where o.property_id=messages.property_id and o.buyer_id=messages.buyer_id)))
);
create policy "public reads published photos" on public.property_photos for select to anon,authenticated using(exists(select 1 from public.properties p where p.id=property_id and (p.status='published' or p.owner_id=auth.uid())));
create policy "owner adds photo metadata" on public.property_photos for insert to authenticated with check(exists(select 1 from public.properties p where p.id=property_id and p.owner_id=auth.uid() and p.status='draft') and storage_path like property_id::text || '/%');
create policy "owner deletes photo metadata" on public.property_photos for delete to authenticated using(exists(select 1 from public.properties p where p.id=property_id and p.owner_id=auth.uid() and p.status='draft'));
create policy "owner sees service requests" on public.service_requests for select to authenticated using(owner_id=auth.uid());
create policy "owner creates service request" on public.service_requests for insert to authenticated with check(owner_id=auth.uid() and status='requested' and (property_id is null or exists(select 1 from public.properties p where p.id=property_id and p.owner_id=auth.uid())));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('property-photos','property-photos',true,10485760,array['image/jpeg','image/png','image/webp'])
 on conflict(id) do nothing;
create policy "public photo access" on storage.objects for select to anon,authenticated using(bucket_id='property-photos' and exists(select 1 from public.property_photos pp join public.properties p on p.id=pp.property_id where pp.storage_path=name and (p.status='published' or p.owner_id=auth.uid())));
create policy "owner uploads draft photos" on storage.objects for insert to authenticated with check(bucket_id='property-photos' and exists(select 1 from public.properties p where p.id::text=split_part(name,'/',1) and p.owner_id=auth.uid() and p.status='draft'));
create policy "owner removes draft photos" on storage.objects for delete to authenticated using(bucket_id='property-photos' and exists(select 1 from public.properties p where p.id::text=split_part(name,'/',1) and p.owner_id=auth.uid() and p.status='draft'));
