-- Only after reviewed smoke tests and backend/catalog build verification.
begin;
set local lock_timeout='5s';
lock table public.products,public.product_size_prices,public.pizza_sizes,public.orders in share row exclusive mode;
do $$begin
 if to_regclass('private.catalog_write_guard') is null or not exists(select 1 from pg_trigger where tgrelid='public.products'::regclass and tgname='product_catalog_valid' and tgenabled='O') then
   raise exception 'Enforcement required before release';
 end if;
end $$;
update private.achado4_maintenance set catalog_paused=false,orders_paused=false where singleton;
commit;
