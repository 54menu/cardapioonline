-- Run as database administrator: psql -v ON_ERROR_STOP=1 -f tests/subscription-eligibility.sql
-- Real RLS/ACL/trigger/RPC tests. Synthetic rows only; all changes roll back.
begin;
create temporary table eligibility_results(test text primary key);
create function pg_temp.ok(value boolean,label text) returns void language plpgsql as $$
begin
 if value is distinct from true then raise exception 'FAILED: %',label; end if;
 insert into eligibility_results values(label);
end $$;
create function pg_temp.order_allowed(sid uuid,expected boolean,label text) returns void language plpgsql as $$
declare denied boolean:=false; result jsonb; rid uuid:=gen_random_uuid();
begin
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 execute 'set local role service_role';
 begin
 result:=public.place_verified_order(sid,rid,jsonb_build_object('customer',jsonb_build_object('name','Regression','phone',replace(rid::text,'-','')),
 'orderType','pickup','items','[]'::jsonb,'subtotal',1,'deliveryFee',0,'total',1,'payment',jsonb_build_object('method','cash')));
 exception when insufficient_privilege then denied:=true;
 end;
 execute 'reset role';
 perform pg_temp.ok(denied<>expected,label||' RPC authorization');
 perform pg_temp.ok(exists(select 1 from public.orders where store_id=sid and request_id=rid)=expected,label||' persisted order');
 perform pg_temp.ok((public.public_store_status(sid) in ('trial','active'))=expected,label||' public effective status');
end $$;

do $$
declare
 u uuid:=gen_random_uuid(); u2 uuid:=gen_random_uuid();
 a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); aborted uuid:=gen_random_uuid();
 today date:=(statement_timestamp() at time zone 'America/Fortaleza')::date;
 due date:=(date_trunc('month',statement_timestamp() at time zone 'America/Fortaleza')+interval '1 month')::date;
 before_sub jsonb; after_sub jsonb; state text; role_name text; cmd text;
 invoice jsonb; result jsonb; constraint_rejected boolean:=false;
begin
 insert into auth.users(id,email,raw_user_meta_data) values(u,u||'@example.invalid','{}'),(u2,u2||'@example.invalid','{}');
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 insert into public.stores(id,owner_id,name,slug,phone) values(a,u,'Regression primary',a::text,'5500000000000');
 execute 'reset role';
 perform pg_temp.ok(exists(select 1 from public.subscriptions where store_id=a and status='trial' and current_period_start=today and trial_ends_at=due and current_period_end=due),'direct store INSERT creates exact next-first-day trial atomically');
 select to_jsonb(s) into before_sub from public.subscriptions s where store_id=a;
 execute 'set local role authenticated';
 perform public.ensure_subscription(a);
 perform public.ensure_subscription(a);
 execute 'reset role';
 select to_jsonb(s) into after_sub from public.subscriptions s where store_id=a;
 perform pg_temp.ok(before_sub=after_sub,'normal onboarding ensure RPC is read-only and idempotent');
 perform pg_temp.order_allowed(a,true,'valid trial');

 update public.subscriptions set trial_ends_at=today where store_id=a;
 perform pg_temp.order_allowed(a,false,'expired trial despite future period end');
 update public.subscriptions set trial_ends_at=due,current_period_end=today where store_id=a;
 perform pg_temp.order_allowed(a,false,'trial expires exactly at exclusive end date');
 update public.subscriptions set status='active',current_period_end=due where store_id=a;
 perform pg_temp.order_allowed(a,true,'valid active');
 update public.subscriptions set current_period_end=today where store_id=a;
 perform pg_temp.order_allowed(a,false,'expired active without cron');
 update public.subscriptions set current_period_end=due,current_period_start=due where store_id=a;
 perform pg_temp.order_allowed(a,false,'future period start');
 update public.subscriptions set current_period_start=null where store_id=a;
 perform pg_temp.order_allowed(a,false,'missing period start');
 update public.subscriptions set current_period_start=today where store_id=a;
 foreach state in array array['blocked','past_due','canceled','grace'] loop
  update public.subscriptions set status=state where store_id=a;
  perform pg_temp.order_allowed(a,false,state||' with future dates');
 end loop;
 begin
  update public.subscriptions set status='unknown' where store_id=a;
 exception when check_violation then constraint_rejected:=true;
 end;
 perform pg_temp.ok(constraint_rejected,'unknown state rejected by schema');
 perform pg_temp.ok(not private.subscription_window_valid('unknown',today,due,due),'unknown state also rejected by eligibility whitelist');
 perform pg_temp.ok(not private.subscription_window_valid(null,today,due,due),'null state fails closed');
 perform pg_temp.ok(not private.subscription_window_valid('active',today,null,due),'null end date fails closed');
 perform pg_temp.ok(not private.subscription_window_valid('trial',today,due,null),'null trial end fails closed');

 -- Bypass attempts use client roles, never administrator privileges.
 foreach role_name in array array['authenticated','anon'] loop
  perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'role',role_name)::text,true);
  foreach cmd in array array[
   format('insert into public.subscriptions(store_id,status,current_period_end) values(%L,''active'',%L)',b,due),
   format('update public.subscriptions set status=''active'' where store_id=%L',a),
   format('update public.subscriptions set current_period_start=%L where store_id=%L',today-1,a),
   format('update public.subscriptions set current_period_end=%L where store_id=%L',due+365,a),
   format('update public.subscriptions set trial_ends_at=%L where store_id=%L',due+365,a),
   format('delete from public.subscriptions where store_id=%L',a),
   format('insert into public.payments(store_id,amount,status) values(%L,19,''approved'')',a),
   format('delete from private.owner_trial_eligibility where owner_id=%L',u),
   format('select public.prepare_billing(%L,19)',a),
   format('select public.apply_verified_payment(''fake'',%L,19,''approved'')',a),
   format('select public.place_verified_order(%L,%L,''{}''::jsonb)',a,gen_random_uuid()),
   format('insert into public.orders(store_id) values(%L)',a),
   format('select private.store_subscription_eligible(%L)',a)
  ] loop
   execute format('set local role %I',role_name);
   begin
    execute cmd;
    raise exception 'Client operation unexpectedly allowed: % %',role_name,cmd;
   exception when insufficient_privilege then null;
   end;
   execute 'reset role';
   perform pg_temp.ok(true,role_name||' denied '||cmd);
  end loop;
 end loop;

 perform set_config('request.jwt.claims',jsonb_build_object('sub',u2,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 begin
  perform public.ensure_subscription(a);
  raise exception 'Foreign ensure allowed';
 exception when insufficient_privilege then null;
 end;
 execute 'reset role';
 perform pg_temp.ok(true,'foreign ensure_subscription denied');

 -- Simulate privileged historical corruption; public paths cannot produce this.
 delete from public.subscriptions where store_id=a;
 perform pg_temp.order_allowed(a,false,'missing subscription');
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 begin
  perform public.ensure_subscription(a);
  raise exception 'ensure restored free trial';
 exception when insufficient_privilege then null;
 end;
 execute 'reset role';
 perform pg_temp.ok(not exists(select 1 from public.subscriptions where store_id=a),'ensure cannot grant replacement trial');
 -- INSERT guard must also reject a service-role write outside the order RPC.
 execute 'set local role service_role';
 begin
  insert into public.orders(store_id,order_number,customer_name,customer_phone,order_type,items,subtotal,total,payment_method)
  values(a,'REGRESSION','Test','5500000000000','pickup','[]',1,1,'cash');
  raise exception 'Direct service INSERT bypass';
 exception when insufficient_privilege then null;
 end;
 execute 'reset role';
 perform pg_temp.ok(true,'table trigger blocks direct service order INSERT');

 execute 'set local role authenticated';
 insert into public.stores(id,owner_id,name,slug,phone,created_at)
 values(b,u,'Regression second',b::text,'5500000000000',now()+interval '10 years');
 execute 'reset role';
 perform pg_temp.ok(exists(select 1 from public.subscriptions where store_id=b and status='blocked' and current_period_end=today and trial_ends_at is null),'second store and forged created_at do not earn trial');
 perform pg_temp.order_allowed(b,false,'second store');
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 delete from public.stores where id=a;
 insert into public.stores(id,owner_id,name,slug,phone) values(c,u,'Regression third',c::text,'5500000000000');
 -- Reusing the original store UUID must not make the old trial renewable.
 insert into public.stores(id,owner_id,name,slug,phone) values(a,u,'Regression same UUID',a::text,'5500000000000');
 execute 'reset role';
 perform pg_temp.ok(exists(select 1 from private.owner_trial_eligibility where owner_id=u and first_store_id=a),'trial consumption survives store deletion');
 perform pg_temp.order_allowed(c,false,'third store after deletion');
 perform pg_temp.order_allowed(a,false,'recreated original UUID');

 -- A failed surrounding transaction cannot leave a store or consume a trial.
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u2,'role','authenticated')::text,true);
 begin
  execute 'set local role authenticated';
  insert into public.stores(id,owner_id,name,slug,phone) values(aborted,u2,'Rollback store',aborted::text,'5500000000000');
  raise exception 'rollback fixture' using errcode='P0002';
 exception when no_data_found then null;
 end;
 execute 'reset role';
 perform pg_temp.ok(not exists(select 1 from public.stores where id=aborted)
   and not exists(select 1 from public.subscriptions where store_id=aborted)
   and not exists(select 1 from private.owner_trial_eligibility where owner_id=u2),'store, subscription and trial ledger roll back together');

 -- Real trusted billing RPCs with synthetic provider records, no external charge.
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 execute 'set local role service_role';
 invoice:=public.prepare_billing(b,19);
 execute 'reset role';
 perform pg_temp.ok((invoice->>'status')='pending' and not private.store_subscription_eligible(b),'PIX invoice does not activate premium');
 update public.payments set mp_payment_id='regression-'||b where id=(invoice->>'id')::uuid;
 execute 'set local role service_role';
 result:=public.apply_verified_payment('regression-'||b,b,19,'pending');
 execute 'reset role';
 perform pg_temp.ok(not private.store_subscription_eligible(b),'pending provider payment does not activate premium');
 execute 'set local role service_role';
 result:=public.apply_verified_payment('regression-'||b,b,19,'approved');
 execute 'reset role';
 perform pg_temp.order_allowed(b,true,'verified payment activates second store');
 select to_jsonb(s) into before_sub from public.subscriptions s where store_id=b;
 execute 'set local role service_role';
 result:=public.apply_verified_payment('regression-'||b,b,19,'approved');
 execute 'reset role';
 select to_jsonb(s) into after_sub from public.subscriptions s where store_id=b;
 perform pg_temp.ok(before_sub=after_sub and (result->>'duplicate')::boolean,'payment replay does not extend dates');
 execute 'set local role service_role';
 invoice:=public.prepare_billing(c,19);
 execute 'reset role';
 update public.payments set mp_payment_id='regression-'||c where id=(invoice->>'id')::uuid;
 update public.subscriptions set status='canceled' where store_id=c;
 execute 'set local role service_role';
 result:=public.apply_verified_payment('regression-'||c,c,19,'approved');
 execute 'reset role';
 perform pg_temp.ok(result->>'subscription_activated'='false','late payment cannot undo cancellation');
 perform pg_temp.order_allowed(c,false,'canceled after payment');
end $$;
select count(*) as passed_assertions,jsonb_agg(test order by test) as tests from eligibility_results;
rollback;

