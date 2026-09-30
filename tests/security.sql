-- Executed after migrations in a single transaction ending with ROLLBACK.
do $$ begin
 if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and not c.relrowsecurity) then raise exception 'RLS disabled'; end if;
 if has_table_privilege('anon','public.orders','SELECT') or has_table_privilege('anon','public.products','UPDATE') then raise exception 'Anonymous data access'; end if;
 if has_column_privilege('authenticated','public.profiles','role','UPDATE') then raise exception 'Role escalation'; end if;
 if has_table_privilege('authenticated','public.subscriptions','UPDATE') then raise exception 'Billing writable'; end if;
end $$;
-- Existing identity is impersonated only in this transaction; no credentials are created.
select set_config('request.jwt.claims',json_build_object('sub',(select owner_id from public.stores limit 1),'role','authenticated')::text,true);
set local role authenticated;
do $$ declare sid uuid; begin
 select id into sid from public.stores where owner_id=auth.uid() limit 1;
 if sid is null then raise exception 'Owner cannot read store'; end if;
 perform 1 from public.profiles where id=auth.uid();
 perform 1 from public.products where store_id=sid;
 if exists(select 1 from public.orders where not private.member_store(store_id)) then raise exception 'Cross-store order leak'; end if;
 begin
  update public.profiles set role='superadmin' where id=auth.uid();
  raise exception 'Role update was allowed';
 exception when insufficient_privilege then null; end;
 begin
  update public.subscriptions set status='active' where store_id=sid;
  raise exception 'Subscription update was allowed';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"anon"}',true);
set local role anon;
do $$ begin
 perform 1 from public.stores limit 1;
 perform 1 from public.products limit 1;
 perform 1 from public.addon_options limit 1;
 perform 1 from public.offer_group_items limit 1;
 begin perform 1 from public.orders; raise exception 'Anonymous orders readable'; exception when insufficient_privilege then null; end;
 begin perform 1 from public.invites; raise exception 'Anonymous invites readable'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
do $$ declare sid uuid:=gen_random_uuid(); pid uuid; end1 date; end2 date; result jsonb; begin
 insert into public.stores(id,owner_id,name,slug,phone) select sid,owner_id,'Transaction test',sid::text,'5500000000000' from public.stores limit 1;
 insert into public.subscriptions(store_id,status,current_period_end) values(sid,'trial','2026-10-01');
 insert into public.payments(store_id,competence,due_date,grace_until,amount,status,mp_payment_id) values(sid,'2026-10','2026-10-01','2026-10-06T23:59:59-03:00',174,'pending',sid::text) returning id into pid;
 perform public.apply_verified_payment(sid::text,sid,174,'approved');
 select current_period_end into end1 from public.subscriptions where store_id=sid;
 perform public.apply_verified_payment(sid::text,sid,174,'approved');
 select current_period_end into end2 from public.subscriptions where store_id=sid;
 if end1<>'2027-04-01'::date or end2<>end1 then raise exception 'Billing period or idempotency failed'; end if;
 begin perform public.apply_verified_payment(sid::text,sid,29,'approved'); raise exception 'Amount mismatch accepted'; exception when raise_exception then if sqlerrm<>'Payment amount mismatch' then raise; end if; end;
end $$;
do $$ declare sid uuid:=gen_random_uuid(); rid uuid:=gen_random_uuid(); a jsonb; b jsonb; payload jsonb; begin
 insert into public.stores(id,owner_id,name,slug,phone) select sid,owner_id,'Transaction test',sid::text,'5500000000000' from public.stores limit 1;
 payload:='{"customer":{"name":"Teste","phone":"5500000000000"},"orderType":"pickup","items":[{"productName":"Item","quantity":1,"itemTotal":10}],"subtotal":10,"deliveryFee":0,"total":10,"payment":{"method":"pix"},"notes":""}'::jsonb;
 a:=public.place_verified_order(sid,rid,payload);
 b:=public.place_verified_order(sid,rid,payload);
 if a->>'id'<>b->>'id' or (select count(*) from public.orders where store_id=sid)<>1 then raise exception 'Duplicate order'; end if;
end $$;
select 'security and billing checks passed; all changes will roll back' as result;
