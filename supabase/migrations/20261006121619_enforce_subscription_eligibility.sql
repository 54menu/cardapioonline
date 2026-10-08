-- Finding 2 only. All policy definitions in storage are intentionally untouched.
-- Preflight: do not guess eligibility for unreviewed historical rows.
lock table public.stores, public.subscriptions in share row exclusive mode;
do $$
begin
 if exists(select 1 from public.stores s left join public.subscriptions b on b.store_id=s.id where b.store_id is null) then
   raise exception 'Unreviewed stores without subscription: reconcile before migration';
 end if;
 if exists(select 1 from public.subscriptions where status in ('trial','active')
   and (current_period_start is null or current_period_start>current_period_end
     or (status='trial' and trial_ends_at is null))) then
   raise exception 'Unreviewed subscription dates: reconcile before migration';
 end if;
end $$;

-- Owner explicitly confirmed this historical payment covers through 2026-11-01.
-- Reconcile the existing record; do not manufacture a provider payment.
update public.subscriptions b
set status='active',current_period_start=date '2026-10-01',
    current_period_end=date '2026-11-01',last_payment_id=p.id
from public.stores s, public.payments p
where s.id=b.store_id and s.slug='dona-lia'
  and p.store_id=s.id and p.status='approved' and p.amount=29
  and p.due_date=date '2026-10-01' and p.mp_payment_id is null
  and b.status='grace' and b.current_period_end=date '2026-10-01';

-- Durable consumption record: intentionally no cascading FK to stores or auth.users.
-- Deleting a store must not recreate its owner's trial eligibility.
create table private.owner_trial_eligibility (
 owner_id uuid primary key,
 first_store_id uuid not null,
 started_on date not null,
 ends_on date not null,
 recorded_at timestamptz not null default now()
);
alter table private.owner_trial_eligibility enable row level security;
revoke all on private.owner_trial_eligibility from public,anon,authenticated,service_role;

-- Existing customers keep their subscription and trial dates.
insert into private.owner_trial_eligibility(owner_id,first_store_id,started_on,ends_on)
select distinct on (s.owner_id) s.owner_id,s.id,
 coalesce(b.current_period_start,(b.created_at at time zone 'America/Fortaleza')::date),
 coalesce(b.trial_ends_at,b.current_period_end)
from public.stores s join public.subscriptions b on b.store_id=s.id
order by s.owner_id,b.created_at,s.id;

create function private.initialize_store_subscription() returns trigger
language plpgsql security definer set search_path='' as $$
declare
 today date := (statement_timestamp() at time zone 'America/Fortaleza')::date;
 due date := (date_trunc('month',statement_timestamp() at time zone 'America/Fortaleza')+interval '1 month')::date;
 eligible_store uuid;
begin
 -- The caller's metadata and stores.created_at never control the trial clock.
 if auth.role() in ('anon','authenticated') and new.owner_id is distinct from auth.uid() then
   raise exception 'Not authorized' using errcode='42501';
 end if;
 insert into private.owner_trial_eligibility(owner_id,first_store_id,started_on,ends_on)
 values(new.owner_id,new.id,today,due) on conflict(owner_id) do nothing
 returning first_store_id into eligible_store;
 insert into public.subscriptions(store_id,plan_amount,status,current_period_start,current_period_end,trial_ends_at)
 values(new.id,19,case when eligible_store=new.id then 'trial' else 'blocked' end,today,
   case when eligible_store=new.id then due else today end,
   case when eligible_store=new.id then due else null end);
 return new;
end $$;
revoke all on function private.initialize_store_subscription() from public,anon,authenticated,service_role;
create trigger initialize_store_subscription after insert on public.stores
for each row execute function private.initialize_store_subscription();

-- Compatibility RPC for old clients: check only; never grant or recreate a trial.
create or replace function public.ensure_subscription(p_store_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
begin
 if not private.owns_store(p_store_id) then raise exception 'Not authorized' using errcode='42501'; end if;
 if not exists(select 1 from public.subscriptions where store_id=p_store_id) then
   raise exception 'Subscription missing' using errcode='42501';
 end if;
 return p_store_id;
end $$;
revoke all on function public.ensure_subscription(uuid) from public,anon;
grant execute on function public.ensure_subscription(uuid) to authenticated;

-- Closed whitelist with exclusive end dates in the existing business timezone.
create function private.subscription_window_valid(p_status text,p_start date,p_end date,p_trial_end date)
returns boolean language sql stable security invoker set search_path='' as $$
 select coalesce(
 p_start <= (statement_timestamp() at time zone 'America/Fortaleza')::date
 and p_end > (statement_timestamp() at time zone 'America/Fortaleza')::date
 and (p_status='active' or (p_status='trial'
   and p_trial_end > (statement_timestamp() at time zone 'America/Fortaleza')::date)),false);
$$;
revoke all on function private.subscription_window_valid(text,date,date,date) from public,anon,authenticated,service_role;

create function private.store_subscription_eligible(p_store_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from public.subscriptions b join public.stores s on s.id=b.store_id
  where b.store_id=p_store_id
   and private.subscription_window_valid(b.status,b.current_period_start,b.current_period_end,b.trial_ends_at)
   and (b.status='active' or exists(
     select 1 from private.owner_trial_eligibility e
     where e.owner_id=s.owner_id and e.first_store_id=s.id
       and b.trial_ends_at<=e.ends_on and b.current_period_end<=e.ends_on
   ))
 );
$$;
revoke all on function private.store_subscription_eligible(uuid) from public,anon,authenticated,service_role;

-- Existing public status RPC now reflects effective eligibility, even if cron is late.
create or replace function public.public_store_status(p_store_id uuid) returns text
language sql stable security definer set search_path='' as $$
 select case when private.store_subscription_eligible(p_store_id)
 then (select status from public.subscriptions where store_id=p_store_id)
 else coalesce((select case when status in ('canceled','past_due') then status else 'blocked' end
   from public.subscriptions where store_id=p_store_id),'blocked') end;
$$;

-- Protect every order INSERT, including trusted API paths that bypass table RLS.
-- Row locks serialize inserts with concurrent cancellation/expiry updates.
create function private.guard_order_subscription() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.stores where id=new.store_id and status='open' for share;
 if not found then raise exception 'Store unavailable' using errcode='42501'; end if;
 perform 1 from public.subscriptions where store_id=new.store_id for share;
 if not private.store_subscription_eligible(new.store_id) then
   raise exception 'Store unavailable' using errcode='42501';
 end if;
 return new;
end $$;
revoke all on function private.guard_order_subscription() from public,anon,authenticated,service_role;
create trigger guard_order_subscription before insert or update of store_id on public.orders
for each row execute function private.guard_order_subscription();

CREATE OR REPLACE FUNCTION public.place_verified_order(p_store_id uuid, p_request_id uuid, p_snapshot jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare existing public.orders%rowtype; number text; sid uuid;
begin
 if p_request_id is null then raise exception 'Request id required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_store_id::text||p_request_id::text,0));
 if not private.store_subscription_eligible(p_store_id) then raise exception 'Store unavailable' using errcode='42501'; end if;
 select * into existing from public.orders where store_id=p_store_id and request_id=p_request_id;
 if found then return existing.snapshot; end if;
 if not exists(select 1 from public.stores where id=p_store_id and status='open') then raise exception 'Store closed'; end if;
 if (select count(*) from public.orders where store_id=p_store_id and customer_phone=p_snapshot#>>'{customer,phone}' and created_at>now()-interval '1 minute')>=3 then raise exception 'Wait before placing another order'; end if;
 sid:=gen_random_uuid();
 number:='PDV-'||to_char(now() at time zone 'America/Fortaleza','YYYYMMDD')||'-'||nextval('public.order_number_seq');
 p_snapshot:=p_snapshot||jsonb_build_object('id',sid,'orderNumber',number,'createdAt',now(),'status','received');
 insert into public.orders(id,store_id,request_id,order_number,customer_name,customer_phone,customer_address,order_type,items,subtotal,delivery_fee,total,payment_method,notes,status,snapshot)
 values(sid,p_store_id,p_request_id,number,p_snapshot#>>'{customer,name}',p_snapshot#>>'{customer,phone}',p_snapshot->'deliveryAddress',p_snapshot->>'orderType',p_snapshot->'items',(p_snapshot->>'subtotal')::numeric,(p_snapshot->>'deliveryFee')::numeric,(p_snapshot->>'total')::numeric,p_snapshot#>>'{payment,method}',p_snapshot->>'notes','received',p_snapshot);
 return p_snapshot;
end $function$;

CREATE OR REPLACE FUNCTION public.apply_verified_payment(p_payment_id text, p_store_id uuid, p_amount numeric, p_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare pay public.payments%rowtype; sub public.subscriptions%rowtype; period_end date; months integer;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_store_id::text,0));
 select * into pay from public.payments where store_id=p_store_id and mp_payment_id=p_payment_id for update;
 if not found then raise exception 'Unknown payment'; end if;
 if pay.amount<>p_amount or p_amount not in (19,114,29,174) then raise exception 'Payment amount mismatch'; end if;
 if pay.status='approved' then return jsonb_build_object('duplicate',true); end if;
 if p_status<>'approved' then
   update public.payments set mp_status=p_status,status=case when p_status in ('rejected','cancelled') then 'overdue' else 'pending' end where id=pay.id;
   return jsonb_build_object('approved',false);
 end if;
 select * into sub from public.subscriptions where store_id=p_store_id for update;
 if not found then raise exception 'Subscription missing'; end if;
 months := case when p_amount in (114,174) then 6 else 1 end;
 period_end := greatest(sub.current_period_end,(pay.due_date+make_interval(months=>months))::date);
 update public.payments set status='approved',mp_status='approved',paid_at=now() where id=pay.id;
 if sub.status='canceled' then
   return jsonb_build_object('approved',true,'subscription_activated',false,'reconciliation_required',true);
 end if;
 update public.subscriptions set status='active',current_period_end=period_end,
   prepaid_until=case when months=6 then period_end else sub.prepaid_until end,
   last_payment_id=pay.id,updated_at=now() where store_id=p_store_id;
 return jsonb_build_object('approved',true,'period_end',period_end);
end $function$;

-- Explicitly preserve client read-only access and server-only payment/order RPCs.
revoke insert,update,delete,truncate,references,trigger on public.subscriptions,public.payments from anon,authenticated;
revoke all on function public.place_verified_order(uuid,uuid,jsonb),
 public.prepare_billing(uuid,numeric),public.apply_verified_payment(text,uuid,numeric,text) from public,anon,authenticated;
grant execute on function public.place_verified_order(uuid,uuid,jsonb),
 public.prepare_billing(uuid,numeric),public.apply_verified_payment(text,uuid,numeric,text) to service_role;
