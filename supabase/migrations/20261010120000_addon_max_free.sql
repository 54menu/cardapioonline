-- Limite de itens gratuitos por grupo de adicionais (ex: molhos das Entradas).
-- max_free NULL = sem limite (comportamento atual preservado).
-- A contagem considera apenas opcoes com price_diff = 0; itens pagos nao sao afetados.
begin;
alter table public.addon_groups
  add column if not exists max_free smallint;
alter table public.addon_groups
  add constraint addon_groups_max_free_check
  check (max_free is null or max_free >= 0);
comment on column public.addon_groups.max_free is
  'Maximo de opcoes gratuitas (price_diff = 0) selecionaveis pelo cliente. NULL = sem limite.';
commit;
