-- Optional cleanup after release. Enforcement remains installed.
begin;
set local lock_timeout='5s';
lock table public.products,public.product_size_prices,public.pizza_sizes,public.orders in share row exclusive mode;
do $$begin
 if exists(select 1 from private.achado4_maintenance where catalog_paused or orders_paused) then
   raise exception 'Release maintenance explicitly before removing it';
 end if;
end $$;
drop trigger a_achado4_maintenance on public.products;
drop trigger a_achado4_maintenance on public.product_size_prices;
drop trigger a_achado4_maintenance on public.pizza_sizes;
drop trigger a_achado4_maintenance on public.orders;
drop function private.achado4_maintenance_guard();
drop table private.achado4_maintenance;
commit;
