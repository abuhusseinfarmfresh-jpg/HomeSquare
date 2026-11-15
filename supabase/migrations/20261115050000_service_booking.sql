-- Complete owner-facing booking management without payments.
alter table public.service_requests add column if not exists preferred_at timestamptz;
alter table public.service_requests add column if not exists contact_phone text;
alter table public.service_requests add column if not exists scheduled_at timestamptz;
alter table public.service_requests add column if not exists staff_notes text not null default '';
create policy "staff reads service bookings" on public.service_requests for select to authenticated
using(exists(select 1 from public.staff_members s where s.user_id=(select auth.uid())));
create or replace function public.staff_update_service(p_id uuid,p_status text,p_scheduled_at timestamptz default null,p_notes text default '')
returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.staff_members s where s.user_id=(select auth.uid())) then raise exception 'Staff access required'; end if;
 if p_status not in ('contacted','scheduled','completed','cancelled') then raise exception 'Invalid service status'; end if;
 if p_status='scheduled' and p_scheduled_at is null then raise exception 'Schedule date required'; end if;
 update public.service_requests set status=p_status,scheduled_at=p_scheduled_at,staff_notes=left(coalesce(p_notes,''),2000) where id=p_id;
 if not found then raise exception 'Booking not found'; end if;
end $$;
revoke all on function public.staff_update_service(uuid,text,timestamptz,text) from public;
grant execute on function public.staff_update_service(uuid,text,timestamptz,text) to authenticated;
-- Read-only published gallery metadata remains accessible; image access uses short-lived signed URLs.
create index if not exists service_requests_status_idx on public.service_requests(status,created_at desc);
