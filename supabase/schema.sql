-- HomeSquare initial PostgreSQL/Supabase schema
-- Run in Supabase SQL editor after creating a project.
create extension if not exists pgcrypto;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default '',
 role text not null default 'buyer' check (role in ('buyer','seller','both')),
 created_at timestamptz not null default now()
);
create table public.properties (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 address text not null,
 suburb text not null,
 state text not null check (state in ('NSW','VIC','QLD','WA','SA','TAS','ACT','NT')),
 postcode text,
 property_type text not null check (property_type in ('House','Apartment','Townhouse','Land')),
 price numeric(14,2) not null check(price>=0),
 beds integer not null default 0 check(beds>=0),
 baths integer not null default 0 check(baths>=0),
 description text not null default '',
 status text not null default 'draft' check(status in ('draft','pending_review','published','archived')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table public.enquiries (
 id uuid primary key default gen_random_uuid(),
 property_id uuid not null references public.properties(id) on delete cascade,
 buyer_id uuid not null references auth.users(id) on delete cascade,
 kind text not null check(kind in ('general','inspection','offer')),
 message text not null check(length(trim(message))>0),
 proposed_amount numeric(14,2) check(proposed_amount>=0),
 created_at timestamptz not null default now()
);
create index properties_search_idx on public.properties(status,state,suburb);
create index enquiries_property_idx on public.enquiries(property_id,created_at desc);
alter table public.profiles enable row level security;
alter table public.properties enable row level security;
alter table public.enquiries enable row level security;
create policy "Read own profile" on public.profiles for select to authenticated using (id=auth.uid());
create policy "Create own profile" on public.profiles for insert to authenticated with check(id=auth.uid());
create policy "Update own profile" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy "Read published or own property" on public.properties for select to authenticated using(status='published' or owner_id=auth.uid());
create policy "Public can browse published" on public.properties for select to anon using(status='published');
create policy "Owners create drafts" on public.properties for insert to authenticated with check(owner_id=auth.uid() and status='draft');
create policy "Owners edit own nonpublished listings" on public.properties for update to authenticated using(owner_id=auth.uid() and status in ('draft','pending_review','archived')) with check(owner_id=auth.uid() and status in ('draft','pending_review','archived'));
create policy "Owners delete own drafts" on public.properties for delete to authenticated using(owner_id=auth.uid() and status='draft');
create policy "Buyers create enquiries" on public.enquiries for insert to authenticated with check(buyer_id=auth.uid() and exists(select 1 from public.properties p where p.id=property_id and p.status='published' and p.owner_id<>auth.uid()));
create policy "Buyers and owners view enquiries" on public.enquiries for select to authenticated using(buyer_id=auth.uid() or exists(select 1 from public.properties p where p.id=property_id and p.owner_id=auth.uid()));
-- No direct client policy to publish properties: add a trusted moderation workflow.
