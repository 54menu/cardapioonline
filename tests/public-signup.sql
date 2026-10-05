-- Run only inside BEGIN / ROLLBACK after the proposed migration.
do $$
declare
 uid uuid := gen_random_uuid();
 invited_uid uuid := gen_random_uuid();
 sid uuid := gen_random_uuid();
 invitation_id uuid;
 invite_token text := gen_random_uuid()::text;
 signup_email text := uid::text || '@example.invalid';
 invited_email text := invited_uid::text || '@example.invalid';
 expected_due date := (date_trunc('month',now() at time zone 'America/Fortaleza') + interval '1 month')::date;
begin
 insert into auth.users(id,email,raw_user_meta_data) values(uid,signup_email,'{"role":"superadmin","store_id":"00000000-0000-0000-0000-000000000000"}');
 if not exists(select 1 from public.profiles where id=uid and role='owner' and store_id is null) then
   raise exception 'Public signup did not create isolated owner';
 end if;
 insert into public.invites(email,token,status,expires_at,created_by) values(invited_email,invite_token,'pending',now()+interval '1 day',uid) returning id into invitation_id;
 insert into auth.users(id,email,raw_user_meta_data) values(invited_uid,invited_email,jsonb_build_object('invite_token',invite_token));
 if not exists(select 1 from public.invites where id=invitation_id and status='accepted' and accepted_by=invited_uid) then raise exception 'Invite not consumed'; end if;
 begin
   insert into auth.users(id,email,raw_user_meta_data) values(gen_random_uuid(),'reuse-'||invited_email,jsonb_build_object('invite_token',invite_token));
   raise exception 'Used invite accepted';
 exception when raise_exception then
   if sqlerrm <> 'A valid invitation for this email is required' then raise; end if;
 end;
 begin
   insert into auth.users(id,email,raw_user_meta_data) values(gen_random_uuid(),'invalid@example.invalid','{"invite_token":"invalid"}');
   raise exception 'Invalid invite accepted';
 exception when raise_exception then
   if sqlerrm <> 'A valid invitation for this email is required' then raise; end if;
 end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',uid,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 insert into public.stores(id,owner_id,name,slug,phone,status) values(sid,uid,'Signup rollback test',sid::text,'5500000000000','open');
 update public.profiles set store_id=sid where id=uid;
 perform public.ensure_subscription(sid);
 perform public.ensure_subscription(sid);
 if not exists(select 1 from public.subscriptions where store_id=sid and status='trial' and trial_ends_at=expected_due and current_period_end=expected_due) then raise exception 'Trial missing or incorrect'; end if;
 if exists(select 1 from public.profiles where id<>uid) then raise exception 'Profile isolation failed'; end if;
 execute 'reset role';
end $$;
select 'Public signup, owner isolation, invites, store creation and trial passed; rolling back all fixtures' as result;
