begin;
create or replace function public.prepare_billing(p_store_id uuid,p_amount numeric) returns jsonb
language plpgsql security definer set search_path='' as $$
declare sub public.subscriptions%rowtype; pay public.payments%rowtype;
 today date := (now() at time zone 'America/Fortaleza')::date; due date;
begin
 if p_amount not in (29,174) then raise exception 'Invalid plan'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_store_id::text,0));
 select * into sub from public.subscriptions where store_id=p_store_id for update;
 if not found then raise exception 'Subscription missing'; end if;
 if sub.status='canceled' then raise exception 'Subscription canceled'; end if;
 if sub.current_period_end>today+30 then raise exception 'Subscription already paid in advance'; end if;
 due := greatest(today,coalesce(sub.current_period_end,today));
 select * into pay from public.payments where store_id=p_store_id and competence=to_char(due,'YYYY-MM') for update;
 if found then
   if pay.status='approved' then raise exception 'Period already paid'; end if;
   if pay.amount<>p_amount then raise exception 'An invoice with a different plan already exists for this period'; end if;
   if pay.grace_until<=now() then raise exception 'Invoice expired; contact support for reconciliation'; end if;
   return to_jsonb(pay);
 end if;
 insert into public.payments(store_id,competence,due_date,grace_until,amount,status)
 values(p_store_id,to_char(due,'YYYY-MM'),due,((least(due+5,today+29))::text||'T23:59:59-03:00')::timestamptz,p_amount,'pending') returning * into pay;
 return to_jsonb(pay);
end $$;
create or replace function public.apply_verified_payment(p_payment_id text,p_store_id uuid,p_amount numeric,p_status text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare pay public.payments%rowtype; sub public.subscriptions%rowtype; period_end date; months integer;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_store_id::text,0));
 select * into pay from public.payments where store_id=p_store_id and mp_payment_id=p_payment_id for update;
 if not found then raise exception 'Unknown payment'; end if;
 if pay.amount<>p_amount or p_amount not in (29,174) then raise exception 'Payment amount mismatch'; end if;
 if pay.status='approved' then return jsonb_build_object('duplicate',true); end if;
 if p_status<>'approved' then
   update public.payments set mp_status=p_status,status=case when p_status in ('rejected','cancelled') then 'overdue' else 'pending' end where id=pay.id;
   return jsonb_build_object('approved',false);
 end if;
 select * into sub from public.subscriptions where store_id=p_store_id for update;
 if not found then raise exception 'Subscription missing'; end if;
 months := case when p_amount=174 then 6 else 1 end;
 period_end := greatest(sub.current_period_end,(pay.due_date+make_interval(months=>months))::date);
 update public.payments set status='approved',mp_status='approved',paid_at=now() where id=pay.id;
 update public.subscriptions set status='active',current_period_end=period_end,
   prepaid_until=case when months=6 then period_end else sub.prepaid_until end,
   last_payment_id=pay.id,updated_at=now() where store_id=p_store_id;
 return jsonb_build_object('approved',true,'period_end',period_end);
end $$;
revoke all on function public.prepare_billing(uuid,numeric),public.apply_verified_payment(text,uuid,numeric,text) from public,anon,authenticated;
grant execute on function public.prepare_billing(uuid,numeric),public.apply_verified_payment(text,uuid,numeric,text) to service_role;
commit;
