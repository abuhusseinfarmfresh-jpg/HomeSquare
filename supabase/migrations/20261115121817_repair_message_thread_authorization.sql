create schema if not exists homesquare_private;
revoke all on schema homesquare_private from public,anon;
grant usage on schema homesquare_private to authenticated;
create or replace function homesquare_private.thread_exists(p_property uuid,p_buyer uuid)
returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from public.messages m where m.property_id=p_property and m.buyer_id=p_buyer and m.sender_id=p_buyer)
$$;
revoke all on function homesquare_private.thread_exists(uuid,uuid) from public,anon;
grant execute on function homesquare_private.thread_exists(uuid,uuid) to authenticated;
drop policy if exists "thread participants send" on public.messages;
create policy "thread participants send" on public.messages for insert to authenticated
with check (
 sender_id=auth.uid()
 and (
   (buyer_id=auth.uid() and exists(select 1 from public.properties p where p.id=property_id and p.status='published' and p.owner_id<>auth.uid()))
   or
   (exists(select 1 from public.properties p where p.id=property_id and p.owner_id=auth.uid())
    and homesquare_private.thread_exists(property_id,buyer_id))
 )
);
