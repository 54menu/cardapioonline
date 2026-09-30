begin;
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, anon;

create or replace function private.owns_store(sid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.stores where id=sid and owner_id=auth.uid());
$$;
create or replace function private.member_store(sid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select private.owns_store(sid) or exists(select 1 from public.profiles where id=auth.uid() and store_id=sid);
$$;
create or replace function public.is_superadmin() returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='superadmin');
$$;
revoke all on function private.owns_store(uuid),private.member_store(uuid),public.is_superadmin() from public;
grant execute on function private.owns_store(uuid),private.member_store(uuid),public.is_superadmin() to authenticated;

-- Replace policies rather than combining new restrictive rules with old permissive rules.
do $$ declare p record; t text; begin
 for p in select * from pg_policies where schemaname='public' loop
   execute format('drop policy %I on public.%I',p.policyname,p.tablename);
 end loop;
 for t in select tablename from pg_tables where schemaname='public' loop
   execute format('alter table public.%I enable row level security',t);
   execute format('revoke all on public.%I from anon, authenticated',t);
 end loop;
end $$;

grant select on public.stores,public.categories,public.products,public.addon_groups,public.addon_options,
 public.neighborhoods,public.store_settings,public.pizza_sizes,public.product_size_prices,
 public.offers,public.offer_groups,public.offer_group_items,public.offer_schedules,
 public.campaigns,public.campaign_offers,public.promotions to anon,authenticated;
grant insert,update,delete on public.stores,public.categories,public.products,public.addon_groups,
 public.addon_options,public.neighborhoods,public.store_settings,public.pizza_sizes,
 public.product_size_prices,public.offers,public.offer_groups,public.offer_group_items,
 public.offer_schedules,public.campaigns,public.campaign_offers,public.promotions to authenticated;
grant select on public.profiles,public.orders,public.subscriptions,public.payments,public.invites to authenticated;
grant update(full_name,avatar_url,store_id) on public.profiles to authenticated;
grant update(status,completed_at,updated_at) on public.orders to authenticated;
grant insert,update,delete on public.invites to authenticated;

create policy store_public on public.stores for select to anon,authenticated using(status in ('open','closed'));
create policy store_owner on public.stores for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy store_staff on public.stores for select to authenticated using(private.member_store(id));
create policy profile_read on public.profiles for select to authenticated using(id=auth.uid() or private.owns_store(store_id) or public.is_superadmin());
create policy profile_update on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());

create or replace function private.guard_profile() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if auth.role() in ('anon','authenticated') then
   if new.role is distinct from old.role or new.id is distinct from old.id or new.email is distinct from old.email then
     raise exception 'Protected profile fields' using errcode='42501';
   end if;
   if new.store_id is distinct from old.store_id and (new.store_id is null or not private.owns_store(new.store_id)) then
     raise exception 'Store assignment not allowed' using errcode='42501';
   end if;
 end if;
 return new;
end $$;
create trigger protect_profile before update on public.profiles for each row execute function private.guard_profile();

do $$ declare t text; public_filter text; begin
 foreach t in array array['categories','products','addon_groups','neighborhoods','store_settings','pizza_sizes','offers','campaigns','promotions'] loop
   public_filter := case t when 'categories' then 'is_active' when 'products' then 'available' when 'neighborhoods' then 'is_active' when 'pizza_sizes' then 'is_active' when 'offers' then 'active' when 'campaigns' then 'active' when 'promotions' then 'is_active' else 'true' end;
   execute format('create policy catalog_public on public.%I for select to anon,authenticated using (%s and exists(select 1 from public.stores s where s.id=store_id and s.status in (''open'',''closed'')))',t,public_filter);
   execute format('create policy catalog_member on public.%I for all to authenticated using(private.member_store(store_id)) with check(private.member_store(store_id))',t);
 end loop;
end $$;

create policy addon_read on public.addon_options for select to anon,authenticated using(exists(select 1 from public.addon_groups g where g.id=group_id));
create policy addon_write on public.addon_options for all to authenticated using(exists(select 1 from public.addon_groups g where g.id=group_id and private.member_store(g.store_id))) with check(exists(select 1 from public.addon_groups g where g.id=group_id and private.member_store(g.store_id)));
create policy prices_read on public.product_size_prices for select to anon,authenticated using(exists(select 1 from public.products p where p.id=product_id) and exists(select 1 from public.pizza_sizes s where s.id=size_id));
create policy prices_write on public.product_size_prices for all to authenticated using(exists(select 1 from public.products p join public.pizza_sizes s on s.store_id=p.store_id where p.id=product_id and s.id=size_id and private.member_store(p.store_id))) with check(exists(select 1 from public.products p join public.pizza_sizes s on s.store_id=p.store_id where p.id=product_id and s.id=size_id and private.member_store(p.store_id)));
create policy groups_read on public.offer_groups for select to anon,authenticated using(exists(select 1 from public.offers o where o.id=offer_id));
create policy groups_write on public.offer_groups for all to authenticated using(exists(select 1 from public.offers o where o.id=offer_id and private.member_store(o.store_id))) with check(exists(select 1 from public.offers o where o.id=offer_id and private.member_store(o.store_id)));
create policy schedules_read on public.offer_schedules for select to anon,authenticated using(exists(select 1 from public.offers o where o.id=offer_id));
create policy schedules_write on public.offer_schedules for all to authenticated using(exists(select 1 from public.offers o where o.id=offer_id and private.member_store(o.store_id))) with check(exists(select 1 from public.offers o where o.id=offer_id and private.member_store(o.store_id)));
create policy items_read on public.offer_group_items for select to anon,authenticated using(exists(select 1 from public.offer_groups g where g.id=group_id));
create policy items_write on public.offer_group_items for all to authenticated using(exists(select 1 from public.offer_groups g join public.offers o on o.id=g.offer_id where g.id=group_id and private.member_store(o.store_id))) with check(exists(select 1 from public.offer_groups g join public.offers o on o.id=g.offer_id join public.products p on p.store_id=o.store_id where g.id=group_id and p.id=product_id and private.member_store(o.store_id)));
create policy links_read on public.campaign_offers for select to anon,authenticated using(exists(select 1 from public.campaigns c where c.id=campaign_id));
create policy links_write on public.campaign_offers for all to authenticated using(exists(select 1 from public.campaigns c where c.id=campaign_id and private.member_store(c.store_id))) with check(exists(select 1 from public.campaigns c join public.offers o on o.store_id=c.store_id where c.id=campaign_id and o.id=offer_id and private.member_store(c.store_id)));
create policy orders_read on public.orders for select to authenticated using(private.member_store(store_id));
create policy orders_update on public.orders for update to authenticated using(private.member_store(store_id)) with check(private.member_store(store_id));
create policy subscription_read on public.subscriptions for select to authenticated using(private.member_store(store_id));
create policy payment_read on public.payments for select to authenticated using(private.member_store(store_id));
create policy invites_admin on public.invites for all to authenticated using(public.is_superadmin()) with check(public.is_superadmin());

create or replace function public.public_store_status(p_store_id uuid) returns text
language sql stable security definer set search_path='' as $$
 select status from public.subscriptions where store_id=p_store_id;
$$;
revoke all on function public.public_store_status(uuid) from public;
grant execute on function public.public_store_status(uuid) to anon,authenticated;
create or replace function public.ensure_subscription(p_store_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare due date := (date_trunc('month',now() at time zone 'America/Fortaleza') + interval '1 month')::date;
begin
 if not private.owns_store(p_store_id) then raise exception 'Not authorized' using errcode='42501'; end if;
 insert into public.subscriptions(store_id,plan_amount,status,current_period_start,current_period_end,trial_ends_at)
 values(p_store_id,29,'trial',(now() at time zone 'America/Fortaleza')::date,due,due) on conflict(store_id) do nothing;
 return p_store_id;
end $$;
revoke all on function public.ensure_subscription(uuid) from public;
grant execute on function public.ensure_subscription(uuid) to authenticated;

create or replace function public.validate_invite(p_token text)
returns table(invite_id uuid,store_name text,store_slug text,is_valid boolean,invite_email text)
language sql stable security definer set search_path='' as $$
 select id,store_name,store_slug,true,email from public.invites where token=p_token and status='pending' and expires_at>now();
$$;
revoke all on function public.validate_invite(text) from public;
grant execute on function public.validate_invite(text) to anon,authenticated;
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path='' as $$
declare invitation public.invites%rowtype;
begin
 select * into invitation from public.invites where token=new.raw_user_meta_data->>'invite_token' for update;
 if not found or invitation.status<>'pending' or invitation.expires_at<=now() or lower(invitation.email)<>lower(new.email) then
   raise exception 'A valid invitation for this email is required';
 end if;
 insert into public.profiles(id,email,full_name,avatar_url,role) values(new.id,new.email,new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'avatar_url','owner');
 update public.invites set status='accepted',accepted_by=new.id,updated_at=now() where id=invitation.id;
 return new;
end $$;
revoke all on function public.handle_new_user() from public,anon,authenticated;

drop policy if exists "Auth can update/delete own images" on storage.objects;
drop policy if exists "Auth can upload product images" on storage.objects;
create policy images_insert on storage.objects for insert to authenticated with check(bucket_id='product-images' and exists(select 1 from public.stores s where s.id::text=(storage.foldername(name))[1] and private.member_store(s.id)));
create policy images_delete on storage.objects for delete to authenticated using(bucket_id='product-images' and exists(select 1 from public.stores s where s.id::text=(storage.foldername(name))[1] and private.member_store(s.id)));

-- Pin all application functions to a trusted search path; new functions use fully qualified names.
do $$ declare f record; begin
 for f in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proconfig is null loop
   execute format('alter function %s set search_path = public, pg_temp',f.signature);
 end loop;
end $$;
commit;
