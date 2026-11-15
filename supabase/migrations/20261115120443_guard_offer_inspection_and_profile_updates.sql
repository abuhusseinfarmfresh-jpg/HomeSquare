create or replace function public.homesquare_guard_participant_decision()
returns trigger language plpgsql set search_path='' as $$
begin
 if to_jsonb(new)-'status' is distinct from to_jsonb(old)-'status' then
   raise exception 'Only the decision status can change';
 end if;
 if tg_table_name='offers' then
   if old.status='submitted' and new.status='withdrawn' and auth.uid()=old.buyer_id then return new; end if;
   if old.status='submitted' and new.status in ('accepted','declined')
      and auth.uid() is not null and current_user='postgres'
      and exists(select 1 from public.properties p where p.id=old.property_id and p.owner_id=auth.uid()) then return new; end if;
 elsif tg_table_name='inspections' then
   if old.status='requested' and new.status='cancelled' and auth.uid()=old.buyer_id then return new; end if;
   if old.status='requested' and new.status in ('confirmed','declined')
      and auth.uid() is not null and current_user='postgres'
      and exists(select 1 from public.properties p where p.id=old.property_id and p.owner_id=auth.uid()) then return new; end if;
 end if;
 raise exception 'Unauthorised decision transition';
end $$;
drop trigger if exists homesquare_guard_offer_decision on public.offers;
create trigger homesquare_guard_offer_decision before update on public.offers for each row execute function public.homesquare_guard_participant_decision();
drop trigger if exists homesquare_guard_inspection_decision on public.inspections;
create trigger homesquare_guard_inspection_decision before update on public.inspections for each row execute function public.homesquare_guard_participant_decision();
create or replace function public.homesquare_guard_profile_identity()
returns trigger language plpgsql set search_path='' as $$
begin
 if new.id is distinct from old.id or new.role is distinct from old.role then
  raise exception 'Profile identity and role cannot be changed';
 end if;
 return new;
end $$;
drop trigger if exists homesquare_guard_profile_identity on public.profiles;
create trigger homesquare_guard_profile_identity before update on public.profiles for each row execute function public.homesquare_guard_profile_identity();
