-- Opcionais por categoria + item cumulativo.
-- addon_group_categories: grupo sem vinculo vale para todas as categorias (comportamento atual).
-- addon_options.cumulative: true = pode repetir (quantidade); false = unidade unica e exclusiva no grupo.
begin;
alter table public.addon_options
  add column if not exists cumulative boolean not null default true;
comment on column public.addon_options.cumulative is
  'true = cliente pode repetir o item (quantidade); false = unidade unica e exclusiva no grupo.';

create table if not exists public.addon_group_categories (
  group_id uuid not null references public.addon_groups(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  created_at timestamp with time zone not null default now(),
  primary key (group_id, category_id)
);
comment on table public.addon_group_categories is
  'Vinculo grupo de opcionais <-> categorias. Grupo sem vinculo aplica-se a todas as categorias.';

grant select on public.addon_group_categories to anon, authenticated;
grant insert, update, delete on public.addon_group_categories to authenticated;

create policy categories_read on public.addon_group_categories
  for select to anon, authenticated
  using (exists (select 1 from public.addon_groups g where g.id = group_id));
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
commit;
