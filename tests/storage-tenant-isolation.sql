-- Execute as the migration/database administrator (psql -v ON_ERROR_STOP=1 -f ...).
-- Real PostgreSQL RLS checks, not mocks. No stored file bytes are touched.
-- All synthetic users, stores and object metadata are rolled back.
begin;
set local storage.allow_delete_query = 'true';
create temporary table storage_test_results(scenario text, assertion text, passed boolean);
create temporary table storage_test_baseline as
select relacl from pg_class where oid='storage.objects'::regclass;

create function pg_temp.check_storage_path(label text, uid uuid, object_path text, allowed boolean)
returns void language plpgsql security invoker as $$
declare
  changed integer;
  denied boolean := false;
  fixture_id uuid;
begin
  perform set_config('request.jwt.claims',jsonb_build_object('sub',uid,'role','authenticated')::text,true);
  execute 'set local role authenticated';
  if current_user <> 'authenticated' then raise exception 'RLS role simulation failed'; end if;
  begin
    insert into storage.objects(bucket_id,name,metadata)
    values('product-images',object_path,'{"revision":1}') returning id into fixture_id;
  exception when insufficient_privilege then denied := true;
  end;
  execute 'reset role';
  if denied = allowed then raise exception '%: INSERT expectation failed',label; end if;
  insert into storage_test_results values(label,'INSERT',true);

  if not allowed then
    -- Synthetic metadata only, including malformed legacy paths, for DELETE/UPDATE tests.
    insert into storage.objects(bucket_id,name,metadata)
    values('product-images',object_path,'{"revision":1}') returning id into fixture_id;
  end if;
  execute 'set local role authenticated';
  delete from storage.objects where id=fixture_id;
  get diagnostics changed = row_count;
  execute 'reset role';
  if changed <> (case when allowed then 1 else 0 end) then
    raise exception '%: DELETE affected % rows',label,changed;
  end if;
  insert into storage_test_results values(label,'DELETE',true);

  if allowed then
    execute 'set local role authenticated';
    insert into storage.objects(bucket_id,name,metadata)
    values('product-images',object_path,'{"revision":2}') returning id into fixture_id;
    execute 'reset role';
    if not exists(select 1 from storage.objects where id=fixture_id and metadata='{"revision":2}'::jsonb) then
      raise exception '%: DELETE + INSERT replacement failed',label;
    end if;
  else
    if not exists(select 1 from storage.objects where id=fixture_id and metadata='{"revision":1}'::jsonb) then
      raise exception '%: victim object was modified',label;
    end if;
  end if;
  insert into storage_test_results values(label,'replacement / original integrity',true);

  -- UPDATE and UPSERT were not authorized before this fix: do not add that capability.
  execute 'set local role authenticated';
  update storage.objects set metadata='{"revision":999}' where id=fixture_id;
  get diagnostics changed = row_count;
  execute 'reset role';
  if changed <> 0 then raise exception '%: unexpected UPDATE permission',label; end if;
  insert into storage_test_results values(label,'UPDATE remains denied',true);

  denied := false;
  execute 'set local role authenticated';
  begin
    insert into storage.objects(bucket_id,name,metadata)
    values('product-images',object_path,'{"revision":999}')
    on conflict(bucket_id,name) where archived_at is null do update set metadata=excluded.metadata;
  exception when insufficient_privilege then denied := true;
  end;
  execute 'reset role';
  if not denied then raise exception '%: unexpected UPSERT permission',label; end if;
  if not exists(select 1 from storage.objects where id=fixture_id
    and metadata=jsonb_build_object('revision',case when allowed then 2 else 1 end)) then
    raise exception '%: UPDATE/UPSERT changed original object',label;
  end if;
  insert into storage_test_results values(label,'UPSERT denied / original integrity',true);
end $$;

do $$
declare
  user_a uuid := gen_random_uuid();
  user_b uuid := gen_random_uuid();
  staff_a uuid := gen_random_uuid();
  store_a uuid := gen_random_uuid();
  store_b uuid := gen_random_uuid();
  test_tag text := gen_random_uuid()::text;
  public_id uuid;
  changed integer;
  denied boolean := false;
begin
  insert into auth.users(id,email,raw_user_meta_data) values
    (user_a,user_a::text||'@example.invalid','{}'),
    (user_b,user_b::text||'@example.invalid','{}'),
    (staff_a,staff_a::text||'@example.invalid','{}');
  insert into public.stores(id,owner_id,name,slug,phone,status) values
    (store_a,user_a,'Loja A',store_a::text,'5500000000000','open'),
    (store_b,user_b,'Loja B',store_b::text,'5500000000000','open');
  update public.profiles set store_id=store_a,role='staff' where id=staff_a;

  perform pg_temp.check_storage_path('A own folder',user_a,store_a||'/'||test_tag||'-a.png',true);
  perform pg_temp.check_storage_path('A nested own folder',user_a,store_a||'/catalog/nested/'||test_tag||'.png',true);
  perform pg_temp.check_storage_path('B own folder',user_b,store_b||'/'||test_tag||'-b.png',true);
  perform pg_temp.check_storage_path('B targets A UUID',user_b,store_a||'/'||test_tag||'-foreign.png',false);
  perform pg_temp.check_storage_path('A targets B UUID',user_a,store_b||'/'||test_tag||'-foreign.png',false);
  perform pg_temp.check_storage_path('B targets nested A',user_b,store_a||'/nested/'||test_tag||'-foreign.png',false);
  perform pg_temp.check_storage_path('member of A owns no store',staff_a,store_a||'/'||test_tag||'-staff.png',true);
  perform pg_temp.check_storage_path('member of A targets B',staff_a,store_b||'/'||test_tag||'-staff.png',false);

  -- Reproduce the original attack: the store owner can edit the store name.
  perform set_config('request.jwt.claims',jsonb_build_object('sub',user_b,'role','authenticated')::text,true);
  execute 'set local role authenticated';
  update public.stores set name=store_b::text||'/exploit' where id=store_b;
  get diagnostics changed = row_count;
  execute 'reset role';
  if changed <> 1 then raise exception 'Could not reproduce malicious store name'; end if;
  perform pg_temp.check_storage_path('B name contains own UUID / attack A',user_b,store_a||'/'||test_tag||'-name-attack.png',false);
  perform pg_temp.check_storage_path('B malicious name / own file',user_b,store_b||'/'||test_tag||'-name-own.png',true);
  update public.stores set name=store_a::text||'/exploit' where id=store_b;
  perform pg_temp.check_storage_path('B name contains victim UUID',user_b,store_a||'/'||test_tag||'-name-victim.png',false);

  perform pg_temp.check_storage_path('leading ../',user_b,'../'||store_a||'/'||test_tag||'.png',false);
  perform pg_temp.check_storage_path('own UUID then ../ victim',user_b,store_b||'/../'||store_a||'/'||test_tag||'.png',false);
  perform pg_temp.check_storage_path('nested traversal',user_b,store_b||'/nested/../../'||store_a||'/'||test_tag||'.png',false);
  perform pg_temp.check_storage_path('dot path segment',user_b,store_b||'/./'||test_tag||'.png',false);
  perform pg_temp.check_storage_path('no UUID',user_b,'not-a-uuid/'||test_tag||'.png',false);
  perform pg_temp.check_storage_path('empty path',user_b,'',false);
  perform pg_temp.check_storage_path('UUID without filename',user_b,store_b::text,false);
  perform pg_temp.check_storage_path('trailing slash',user_b,store_b||'/',false);
  perform pg_temp.check_storage_path('leading slash',user_b,'/'||store_b||'/'||test_tag||'.png',false);
  perform pg_temp.check_storage_path('empty intermediate segment',user_b,store_b||'//'||test_tag||'.png',false);
  perform pg_temp.check_storage_path('backslash traversal',user_b,store_b||'/'||chr(92)||'..'||chr(92)||test_tag||'.png',false);

  insert into storage.objects(bucket_id,name) values('product-images',store_a||'/'||test_tag||'-public.png') returning id into public_id;
  perform set_config('request.jwt.claims','{"role":"anon"}',true);
  execute 'set local role anon';
  if not exists(select 1 from storage.objects where id=public_id) then
    raise exception 'Anonymous public read broken';
  end if;
  begin
    insert into storage.objects(bucket_id,name) values('product-images',store_a||'/'||test_tag||'-anon.png');
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Anonymous upload allowed'; end if;
  delete from storage.objects where id=public_id;
  get diagnostics changed = row_count;
  execute 'reset role';
  if changed <> 0 then raise exception 'Anonymous delete allowed'; end if;
  insert into storage_test_results values
    ('public catalog','anonymous SELECT allowed',true),
    ('public catalog','anonymous INSERT denied',true),
    ('public catalog','anonymous DELETE denied',true);

  if (select relacl from pg_class where oid='storage.objects'::regclass)
     is distinct from (select relacl from storage_test_baseline) then
    raise exception 'Table grants changed during tests';
  end if;
  if not exists(select 1 from storage.buckets where id='product-images' and public) then
    raise exception 'Bucket is no longer public';
  end if;
  insert into storage_test_results values('least privilege','existing table grants preserved during test',true);
end $$;
select scenario,count(*) as assertions,bool_and(passed) as passed
from storage_test_results group by scenario order by scenario;
rollback;
