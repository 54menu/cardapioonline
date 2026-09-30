begin;
create table if not exists public.billing_notices (
 id uuid primary key default gen_random_uuid(),
 store_id uuid not null references public.stores(id) on delete cascade,
 notice_date date not null,
 message text not null,
 unique(store_id,notice_date)
);
alter table public.billing_notices enable row level security;
revoke all on public.billing_notices from anon,authenticated;
grant select on public.billing_notices to authenticated;
create policy notices_owner on public.billing_notices for select to authenticated using(private.member_store(store_id));
create or replace function private.process_subscription_cycle() returns void
language plpgsql security definer set search_path='' as $$
declare today date := (now() at time zone 'America/Fortaleza')::date;
begin
 update public.payments set status='overdue' where status='pending' and grace_until<now();
 update public.subscriptions set status='grace' where status in ('trial','active') and current_period_end<=today;
 insert into public.billing_notices(store_id,notice_date,message)
 select store_id,today,case when today>current_period_end+5 then 'Assinatura vencida. Gere o PIX no painel para regularizar.' else 'Sua assinatura está no período de renovação. Gere o PIX no painel até o fim da carência.' end
 from public.subscriptions where status in ('grace','past_due','blocked') and today>=current_period_end
 and (today-current_period_end in (0,2,4,6)) on conflict(store_id,notice_date) do nothing;
 update public.subscriptions set status='blocked' where status in ('grace','past_due') and today>current_period_end+5;
end $$;
revoke all on function private.process_subscription_cycle() from public,anon,authenticated;
-- Native scheduler avoids keeping a service-role credential in GitHub Actions.
create extension if not exists pg_cron;
do $$ begin
 if not exists(select 1 from cron.job where jobname='zapmenu-subscription-cycle') then
  perform cron.schedule('zapmenu-subscription-cycle','10 3 * * *','select private.process_subscription_cycle()');
 end if;
end $$;
commit;
