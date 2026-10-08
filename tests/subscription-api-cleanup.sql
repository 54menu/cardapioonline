-- psql -v ON_ERROR_STOP=1 -v fixtures='[manifest]' -f tests/subscription-api-cleanup.sql
-- Refuses non-test identities. Retain the exact manifest returned by setup.
begin;
select set_config('test.fixture_manifest', :'fixtures', true);
create temporary table cleanup_owners as
select distinct u.id from auth.users u
join jsonb_to_recordset(current_setting('test.fixture_manifest')::jsonb) as f(owner_id uuid)
on f.owner_id=u.id
where u.raw_user_meta_data->>'security_test'='subscription-eligibility'
  and u.email='subscription-regression-'||u.id||'@example.invalid';
do $$
begin
 if (select count(*) from cleanup_owners) <>
 (select count(distinct owner_id) from jsonb_to_recordset(current_setting('test.fixture_manifest')::jsonb) as f(owner_id uuid))
 then raise exception 'Fixture cleanup identity mismatch'; end if;
end $$;
delete from private.owner_trial_eligibility where owner_id in (select id from cleanup_owners);
delete from auth.users where id in (select id from cleanup_owners);
commit;

