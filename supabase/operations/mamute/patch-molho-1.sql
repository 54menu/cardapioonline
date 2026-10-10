-- Mamute: entradas pedem no máximo 1 molho (idempotente, sem apagar o cardápio).
-- Rode no SQL Editor do Supabase após as migrações (ou sozinho: o bloco 1 é idempotente).
-- Loja: a5f88e35-f150-4c37-a7bd-2220e02ad2c8 (pizzaria-mamute)

-- 1) Schema (pode rodar de novo sem erro)
alter table public.addon_groups add column if not exists max_free smallint;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'addon_groups_max_free_check') then
    alter table public.addon_groups
      add constraint addon_groups_max_free_check check (max_free is null or max_free >= 0);
  end if;
end $$;
alter table public.addon_options add column if not exists cumulative boolean not null default true;
create table if not exists public.addon_group_categories (
  group_id uuid not null references public.addon_groups(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  created_at timestamp with time zone not null default now(),
  primary key (group_id, category_id)
);
grant select on public.addon_group_categories to anon, authenticated;
grant insert, update, delete on public.addon_group_categories to authenticated;
drop policy if exists categories_read on public.addon_group_categories;
create policy categories_read on public.addon_group_categories
  for select to anon, authenticated
  using (exists (select 1 from public.addon_groups g where g.id = group_id));
drop policy if exists categories_write on public.addon_group_categories;
create policy categories_write on public.addon_group_categories
  for all to authenticated
  using (exists (select 1 from public.addon_groups g where g.id = group_id and private.member_store(g.store_id)))
  with check (exists (
    select 1 from public.addon_groups g
    join public.categories c on c.store_id = g.store_id
    where g.id = group_id and c.id = category_id and private.member_store(g.store_id)
  ));
create index if not exists idx_addon_group_categories_group on public.addon_group_categories using btree (group_id);
create index if not exists idx_addon_group_categories_category on public.addon_group_categories using btree (category_id);

-- 2) Grupo do molho: escolha única, máx 1 grátis
update public.addon_groups
set name = 'Adicional Molho (Entradas)',
    title = 'Escolha o molho',
    type = 'single',
    required = false,
    max_free = 1
where store_id = 'a5f88e35-f150-4c37-a7bd-2220e02ad2c8'
  and name in ('Adicional Molho (Entradas)', 'Adicionais Molhos (Entradas)');

-- 3) Cada molho é exclusivo (não repete, não combina com outro)
update public.addon_options
set cumulative = false
where group_id in (
  select id from public.addon_groups
  where store_id = 'a5f88e35-f150-4c37-a7bd-2220e02ad2c8'
    and name = 'Adicional Molho (Entradas)'
);

-- 4) Molhos valem só para Entradas
insert into public.addon_group_categories (group_id, category_id)
select g.id, c.id
from public.addon_groups g
join public.categories c on c.store_id = g.store_id and c.name = 'Entradas'
where g.store_id = 'a5f88e35-f150-4c37-a7bd-2220e02ad2c8'
  and g.name = 'Adicional Molho (Entradas)'
on conflict do nothing;

-- 5) Entradas permitem adicional
update public.products
set has_extras = true
where store_id = 'a5f88e35-f150-4c37-a7bd-2220e02ad2c8'
  and category_id in (
    select id from public.categories
    where store_id = 'a5f88e35-f150-4c37-a7bd-2220e02ad2c8' and name = 'Entradas'
  );

-- Conferência (esperado: 1 grupo single/max 1, 3 opções exclusivas, 1 vínculo, 7 produtos Entradas com extras)
select g.name, g.type, g.required, g.max_free,
  (select count(*) from public.addon_options o where o.group_id = g.id) as opcoes,
  (select count(*) from public.addon_options o where o.group_id = g.id and o.cumulative = false) as exclusivas,
  (select count(*) from public.addon_group_categories l where l.group_id = g.id) as vinculos
from public.addon_groups g
where g.store_id = 'a5f88e35-f150-4c37-a7bd-2220e02ad2c8';
