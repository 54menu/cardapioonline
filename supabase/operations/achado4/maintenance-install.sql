-- Operational script, NOT a schema-history migration. Execute as database owner.
-- Blocks all actors, including service_role; no client flag or test bypass.
begin;
set local lock_timeout='5s';
lock table public.products,public.product_size_prices,public.pizza_sizes,public.orders in share row exclusive mode;
create schema if not exists private;
create table if not exists private.achado4_maintenance (
 singleton boolean primary key default true check(singleton),
 catalog_paused boolean not null, orders_paused boolean not null
);
revoke all on private.achado4_maintenance from public,anon,authenticated,service_role;
alter table private.achado4_maintenance enable row level security;
insert into private.achado4_maintenance values(true,true,true)
on conflict(singleton) do update set catalog_paused=true,orders_paused=true;
create or replace function private.achado4_maintenance_guard() returns trigger
language plpgsql security definer set search_path='' as $$
declare paused boolean;
begin
 select case when tg_table_name='orders' then orders_paused else catalog_paused end
 into paused from private.achado4_maintenance where singleton;
 if paused is distinct from false then
   raise exception 'Manutenção temporária. Tente novamente após a liberação.' using errcode='55000';
 end if;
 return null;
end $$;
revoke all on function private.achado4_maintenance_guard() from public,anon,authenticated,service_role;
drop trigger if exists a_achado4_maintenance on public.products;
create trigger a_achado4_maintenance before insert or update or delete on public.products for each statement execute function private.achado4_maintenance_guard();
drop trigger if exists a_achado4_maintenance on public.product_size_prices;
create trigger a_achado4_maintenance before insert or update or delete on public.product_size_prices for each statement execute function private.achado4_maintenance_guard();
drop trigger if exists a_achado4_maintenance on public.pizza_sizes;
create trigger a_achado4_maintenance before insert or update or delete on public.pizza_sizes for each statement execute function private.achado4_maintenance_guard();
drop trigger if exists a_achado4_maintenance on public.orders;
create trigger a_achado4_maintenance before insert on public.orders for each statement execute function private.achado4_maintenance_guard();
commit;
