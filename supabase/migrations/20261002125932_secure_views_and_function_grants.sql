alter view public.v_offers_full set (security_invoker = true);
alter view public.v_store_menu set (security_invoker = true);
alter view public.v_recent_orders set (security_invoker = true);
revoke all on public.v_offers_full, public.v_store_menu, public.v_recent_orders from public, anon, authenticated;
grant select on public.v_offers_full, public.v_store_menu to anon, authenticated;
grant select on public.v_recent_orders to authenticated;
grant select on public.v_offers_full, public.v_store_menu, public.v_recent_orders to service_role;
revoke execute on function public.ensure_subscription(uuid), public.is_superadmin() from anon;
