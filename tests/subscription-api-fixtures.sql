-- Administrator-only HTTP fixtures. Run after migration, retain returned manifest.
-- Delete only manifest owner_ids from auth.users and private.owner_trial_eligibility after HTTP tests.
begin;
create temporary table api_fixtures(scenario text,owner_id uuid,store_id uuid,product_id uuid,allowed boolean);
do $$
declare scenario text; u uuid; s uuid; category uuid; product uuid; extra uuid;
today date:=(statement_timestamp() at time zone 'America/Fortaleza')::date;
run_id uuid:=gen_random_uuid();
begin
 foreach scenario in array array['missing','trial','trial_expired','active','active_expired','blocked','past_due','canceled','grace','future_start','second_store'] loop
  u:=gen_random_uuid();s:=gen_random_uuid();category:=gen_random_uuid();product:=gen_random_uuid();
  insert into auth.users(id,email,raw_user_meta_data) values(u,'subscription-regression-'||u||'@example.invalid',jsonb_build_object('security_test','subscription-eligibility','run_id',run_id));
  if scenario='second_store' then
   extra:=gen_random_uuid();
   insert into public.stores(id,owner_id,name,slug,phone) values(extra,u,'SECURITY TEST FIRST STORE',extra::text,'5500000000000');
  end if;
  insert into public.stores(id,owner_id,name,slug,phone,status,min_order_value) values(s,u,'SECURITY TEST '||scenario,s::text,'5500000000000','open',0);
  insert into public.categories(id,store_id,name) values(category,s,'SECURITY TEST');
  insert into public.products(id,store_id,category_id,name,base_price,is_pizza,has_crusts,has_extras) values(product,s,category,'SECURITY TEST',1,false,false,false);
  if scenario='missing' then delete from public.subscriptions where store_id=s;
  elsif scenario='trial_expired' then update public.subscriptions set trial_ends_at=today where store_id=s;
  elsif scenario='active' then update public.subscriptions set status='active' where store_id=s;
  elsif scenario='active_expired' then update public.subscriptions set status='active',current_period_end=today where store_id=s;
  elsif scenario='future_start' then update public.subscriptions set status='active',current_period_start=today+1 where store_id=s;
  elsif scenario in ('blocked','past_due','canceled','grace') then update public.subscriptions set status=scenario where store_id=s;
  end if;
  insert into api_fixtures values(scenario,u,s,product,scenario in ('trial','active'));
 end loop;
end $$;
select jsonb_agg(to_jsonb(f) order by scenario) as fixtures from api_fixtures f;
commit;

