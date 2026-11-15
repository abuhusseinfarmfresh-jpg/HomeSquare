create or replace function public.staff_review_ownership(p_property uuid,p_approve boolean)
returns void language plpgsql security definer set search_path='' as $$
declare v_check public.ownership_checks%rowtype;
begin
 if auth.uid() is null or not exists(select 1 from public.staff_members s where s.user_id=auth.uid()) then
   raise exception 'Staff access required';
 end if;
 select * into v_check from public.ownership_checks where property_id=p_property and status='pending' for update;
 if not found then raise exception 'No pending ownership check'; end if;
 if p_approve and (
    v_check.evidence_path is null or
    not exists(select 1 from storage.objects o where o.bucket_id='ownership-evidence' and o.name=v_check.evidence_path)
 ) then raise exception 'Uploaded ownership evidence required'; end if;
 update public.ownership_checks set status=case when p_approve then 'verified' else 'rejected' end,
 reviewer_id=auth.uid(),reviewed_at=now() where property_id=p_property and status='pending';
end $$;
