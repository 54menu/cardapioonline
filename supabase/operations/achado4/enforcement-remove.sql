-- Maintenance must be active; restore the compatibility RPC FIRST.
begin;
set local lock_timeout='5s';
lock table public.products,public.product_size_prices,public.pizza_sizes in share row exclusive mode;
do $$begin
 if not coalesce((select catalog_paused and orders_paused from private.achado4_maintenance where singleton),false) then raise exception 'Maintenance required'; end if;
 if pg_get_functiondef('public.save_product_with_prices(uuid,uuid,jsonb,jsonb)'::regprocedure) like '%set constraints public.product_catalog_valid%' then raise exception 'Restore compatibility RPC first'; end if;
end $$;
drop trigger product_catalog_lock on public.products;
drop trigger product_price_catalog_lock on public.product_size_prices;
drop trigger pizza_size_catalog_lock on public.pizza_sizes;
drop trigger product_catalog_valid on public.products;
drop trigger product_price_catalog_valid on public.product_size_prices;
drop trigger pizza_size_catalog_valid on public.pizza_sizes;
drop trigger catalog_statement_fence on public.products;
drop trigger catalog_statement_fence on public.product_size_prices;
drop trigger catalog_statement_fence on public.pizza_sizes;
drop function private.enforce_product_catalog();
drop function private.check_product_catalog(uuid);
drop function private.lock_product_catalog();
drop function private.catalog_statement_fence();
drop table private.catalog_write_guard;
commit;
