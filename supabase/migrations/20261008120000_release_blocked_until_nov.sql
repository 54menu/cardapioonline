-- Liberacao manual solicitada pelo owner em 2026-10-08.
-- Lojas bloqueadas (cantinho-da-ju, napolle, pizzariaparaiba) voltam a operar
-- com prazo ate 2026-11-01. Nao cria pagamento; apenas estende a vigencia.
begin;
update public.subscriptions
set status = 'active',
    current_period_start = least(current_period_start, (now() at time zone 'America/Fortaleza')::date),
    current_period_end = date '2026-11-01',
    updated_at = now()
where status in ('blocked', 'past_due', 'grace');
commit;
