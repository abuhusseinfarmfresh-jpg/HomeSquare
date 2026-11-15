create or replace function homesquare_private.thread_exists(p_property uuid,p_buyer uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists (
    select 1
    from public.messages m
    join public.properties p on p.id=m.property_id
    where m.property_id=p_property and m.buyer_id=p_buyer
      and m.sender_id=p_buyer and p.owner_id=(select auth.uid())
  )
$$;

alter policy "thread participants send" on public.messages
with check (
  sender_id=(select auth.uid()) and (
    (buyer_id=(select auth.uid()) and exists (
      select 1 from public.properties p
      where p.id=messages.property_id and p.status='published'
        and p.owner_id<>(select auth.uid())
    ))
    or (
      exists (
        select 1 from public.properties p
        where p.id=messages.property_id and p.owner_id=(select auth.uid())
      ) and (
        homesquare_private.thread_exists(property_id,buyer_id)
        or exists (select 1 from public.enquiries e where e.property_id=messages.property_id and e.buyer_id=messages.buyer_id)
        or exists (select 1 from public.inspections i where i.property_id=messages.property_id and i.buyer_id=messages.buyer_id)
        or exists (select 1 from public.offers o where o.property_id=messages.property_id and o.buyer_id=messages.buyer_id)
      )
    )
  )
);
