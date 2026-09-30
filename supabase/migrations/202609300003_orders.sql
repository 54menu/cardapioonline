begin;
alter table public.orders add column if not exists request_id uuid;
alter table public.orders add column if not exists snapshot jsonb;
create unique index if not exists orders_request_key on public.orders(store_id,request_id);
create sequence if not exists public.order_number_seq;
revoke all on sequence public.order_number_seq from public,anon,authenticated;
create or replace function public.place_verified_order(p_store_id uuid,p_request_id uuid,p_snapshot jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare existing public.orders%rowtype; number text; sid uuid;
begin
 if p_request_id is null then raise exception 'Request id required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_store_id::text||p_request_id::text,0));
 select * into existing from public.orders where store_id=p_store_id and request_id=p_request_id;
 if found then return existing.snapshot; end if;
 if not exists(select 1 from public.stores where id=p_store_id and status='open') then raise exception 'Store closed'; end if;
 if exists(select 1 from public.subscriptions where store_id=p_store_id and status in ('blocked','past_due','canceled')) then raise exception 'Store unavailable'; end if;
 if (select count(*) from public.orders where store_id=p_store_id and customer_phone=p_snapshot#>>'{customer,phone}' and created_at>now()-interval '1 minute')>=3 then raise exception 'Wait before placing another order'; end if;
 sid:=gen_random_uuid();
 number:='PDV-'||to_char(now() at time zone 'America/Fortaleza','YYYYMMDD')||'-'||nextval('public.order_number_seq');
 p_snapshot:=p_snapshot||jsonb_build_object('id',sid,'orderNumber',number,'createdAt',now(),'status','received');
 insert into public.orders(id,store_id,request_id,order_number,customer_name,customer_phone,customer_address,order_type,items,subtotal,delivery_fee,total,payment_method,notes,status,snapshot)
 values(sid,p_store_id,p_request_id,number,p_snapshot#>>'{customer,name}',p_snapshot#>>'{customer,phone}',p_snapshot->'deliveryAddress',p_snapshot->>'orderType',p_snapshot->'items',(p_snapshot->>'subtotal')::numeric,(p_snapshot->>'deliveryFee')::numeric,(p_snapshot->>'total')::numeric,p_snapshot#>>'{payment,method}',p_snapshot->>'notes','received',p_snapshot);
 return p_snapshot;
end $$;
revoke all on function public.place_verified_order(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.place_verified_order(uuid,uuid,jsonb) to service_role;
commit;
