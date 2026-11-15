revoke execute on function public.seller_decide_inspection(uuid,text) from public, anon;
revoke execute on function public.seller_decide_offer(uuid,text) from public, anon;
revoke execute on function public.staff_review_listing(uuid,boolean,text) from public, anon;
revoke execute on function public.staff_review_ownership(uuid,boolean) from public, anon;
revoke execute on function public.staff_update_service(uuid,text,timestamptz,text) from public, anon;
grant execute on function public.seller_decide_inspection(uuid,text),public.seller_decide_offer(uuid,text),public.staff_review_listing(uuid,boolean,text),public.staff_review_ownership(uuid,boolean),public.staff_update_service(uuid,text,timestamptz,text) to authenticated;
