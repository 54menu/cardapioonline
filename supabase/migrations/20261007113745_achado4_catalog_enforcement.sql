begin;
-- Existing inconsistent rows are not rewritten or scanned. Every subsequent
-- mutation of a product or its associations must leave that product valid.
create schema if not exists private;
create table private.catalog_write_guard (
 store_id uuid primary key, revision bigint not null default 0
);
revoke all on private.catalog_write_guard from public,anon,authenticated;
alter table private.catalog_write_guard enable row level security;

-- A real write serializes changes per store, including repeatable-read callers.
-- Unlike an advisory lock alone it also detects stale transaction snapshots.
create function private.lock_product_catalog() returns trigger
language plpgsql security definer set search_path='' as $$
declare ids uuid[]; sid uuid;
begin
 if tg_table_name='product_size_prices' then
   select array_agg(distinct p.store_id) into ids from public.products p
   where p.id in (case when tg_op<>'INSERT' then old.product_id end,case when tg_op<>'DELETE' then new.product_id end);
 else
   ids:=array[case when tg_op<>'INSERT' then old.store_id end,case when tg_op<>'DELETE' then new.store_id end];
 end if;
 for sid in select distinct x from unnest(ids) x where x is not null order by x loop
   insert into private.catalog_write_guard(store_id,revision) values(sid,1)
   on conflict(store_id) do update set revision=private.catalog_write_guard.revision+1;
 end loop;
 if tg_table_name='product_size_prices' and tg_op<>'DELETE' then
   if new.price is null or new.price<=0 or new.price::text in ('NaN','Infinity','-Infinity') then
     raise exception 'Preço por tamanho deve ser finito e maior que zero' using errcode='23514';
   end if;
   if not exists(select 1 from public.products p join public.pizza_sizes s on s.store_id=p.store_id where p.id=new.product_id and s.id=new.size_id) then
     raise exception 'Produto e tamanho devem pertencer à mesma loja' using errcode='23514';
   end if;
 end if;
 if tg_op='DELETE' then return old; end if;return new;
end $$;
revoke all on function private.lock_product_catalog() from public,anon,authenticated;

create function private.check_product_catalog(pid uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.products p where p.id=pid and p.is_pizza and p.available
   and not exists(select 1 from public.product_size_prices v join public.pizza_sizes s on s.id=v.size_id
      where v.product_id=p.id and s.store_id=p.store_id and s.is_active and v.price>0 and v.price::text not in ('NaN','Infinity','-Infinity'))) then
   raise exception 'Pizza disponível precisa de pelo menos um tamanho ativo com preço válido (produto %)',pid using errcode='23514';
 end if;
end $$;
revoke all on function private.check_product_catalog(uuid) from public,anon,authenticated;

create function private.enforce_product_catalog() returns trigger
language plpgsql security definer set search_path='' as $$
declare pid uuid;
begin
 if tg_table_name='products' then
   if tg_op<>'DELETE' then perform private.check_product_catalog(new.id); end if;
 elsif tg_table_name='product_size_prices' then
   if tg_op<>'INSERT' then perform private.check_product_catalog(old.product_id); end if;
   if tg_op<>'DELETE' then perform private.check_product_catalog(new.product_id); end if;
 else
   for pid in select distinct v.product_id from public.product_size_prices v
       where v.size_id in (case when tg_op<>'INSERT' then old.id end,case when tg_op<>'DELETE' then new.id end) loop
     perform private.check_product_catalog(pid);
   end loop;
 end if;
 return null;
end $$;
revoke all on function private.enforce_product_catalog() from public,anon,authenticated;

create trigger product_catalog_lock before insert or update or delete on public.products
for each row execute function private.lock_product_catalog();
create trigger product_price_catalog_lock before insert or update or delete on public.product_size_prices
for each row execute function private.lock_product_catalog();
create trigger pizza_size_catalog_lock before insert or update or delete on public.pizza_sizes
for each row execute function private.lock_product_catalog();
create constraint trigger product_catalog_valid after insert or update on public.products
deferrable initially deferred for each row execute function private.enforce_product_catalog();
create constraint trigger product_price_catalog_valid after insert or update or delete on public.product_size_prices
deferrable initially deferred for each row execute function private.enforce_product_catalog();
create constraint trigger pizza_size_catalog_valid after insert or update or delete on public.pizza_sizes
deferrable initially deferred for each row execute function private.enforce_product_catalog();

-- Invoker retains the existing RLS policies. No grants on catalog tables added.
-- This is a full editor payload; only explicitly listed product fields are used.

create function private.catalog_statement_fence() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into private.catalog_write_guard(store_id,revision) values('00000000-0000-0000-0000-000000000000',1)
 on conflict(store_id) do update set revision=private.catalog_write_guard.revision+1;
 return null;
end $$;
revoke all on function private.catalog_statement_fence() from public,anon,authenticated;
create trigger catalog_statement_fence before insert or update or delete on public.products
for each statement execute function private.catalog_statement_fence();
create trigger catalog_statement_fence before insert or update or delete on public.product_size_prices
for each statement execute function private.catalog_statement_fence();
create trigger catalog_statement_fence before insert or update or delete on public.pizza_sizes
for each statement execute function private.catalog_statement_fence();
create or replace function public.save_product_with_prices(p_store_id uuid,p_product_id uuid,p_product jsonb,p_prices jsonb)
returns public.products language plpgsql security invoker set search_path='' as $$
declare saved public.products; entry jsonb; pid uuid:=coalesce(p_product_id,gen_random_uuid()); amount numeric;
begin
 set constraints public.product_catalog_valid,public.product_price_catalog_valid,public.pizza_size_catalog_valid deferred;
 if auth.uid() is null or not private.member_store(p_store_id) then
   raise exception 'Loja não autorizada' using errcode='42501';
 end if;
 if jsonb_typeof(p_product) is distinct from 'object' or jsonb_typeof(p_prices) is distinct from 'array' then
   raise exception 'Cadastro inválido' using errcode='22023';
 end if;
 if jsonb_array_length(p_prices)>100 then raise exception 'Quantidade de tamanhos inválida'; end if;
 -- Acquire the statement fence before the first tuple lock. No product is changed.
 update public.products set id=id where false;
 if p_product_id is not null then
   select * into saved from public.products where id=pid and store_id=p_store_id for update;
   if not found then raise exception 'Produto não autorizado' using errcode='42501'; end if;
   update public.products set name=p_product->>'name',category_id=(p_product->>'category_id')::uuid,
    description=p_product->>'description',image_url=p_product->>'image_url',codigo=(p_product->>'codigo')::integer,
    is_pizza=(p_product->>'is_pizza')::boolean,available=(p_product->>'available')::boolean,
    has_crusts=(p_product->>'has_crusts')::boolean,has_extras=(p_product->>'has_extras')::boolean,
    is_featured=(p_product->>'is_featured')::boolean,featured_order=(p_product->>'featured_order')::integer,
    base_price=case when (p_product->>'is_pizza')::boolean then 0 else (p_product->>'base_price')::numeric end
   where id=pid and store_id=p_store_id returning * into saved;
 else
   insert into public.products(id,store_id,name,category_id,description,image_url,codigo,is_pizza,available,has_crusts,has_extras,is_featured,featured_order,base_price)
   values(pid,p_store_id,p_product->>'name',(p_product->>'category_id')::uuid,p_product->>'description',p_product->>'image_url',
    (p_product->>'codigo')::integer,(p_product->>'is_pizza')::boolean,(p_product->>'available')::boolean,
    (p_product->>'has_crusts')::boolean,(p_product->>'has_extras')::boolean,(p_product->>'is_featured')::boolean,
    (p_product->>'featured_order')::integer,case when (p_product->>'is_pizza')::boolean then 0 else (p_product->>'base_price')::numeric end)
   returning * into saved;
 end if;
 if not saved.is_pizza and jsonb_array_length(p_prices)>0 then raise exception 'Produto comum não recebe preços de pizza'; end if;
 if (select count(*)<>count(distinct e->>'size_id') from jsonb_array_elements(p_prices) e) then raise exception 'Tamanho repetido'; end if;
 delete from public.product_size_prices where product_id=pid;
 for entry in select * from jsonb_array_elements(p_prices) loop
   if jsonb_typeof(entry->'price') is distinct from 'number' then raise exception 'Preço deve ser numérico'; end if;
   amount:=(entry->>'price')::numeric;
   if amount<=0 or amount>99999999.99 or amount<>round(amount,2) then raise exception 'Preço inválido'; end if;
   insert into public.product_size_prices(product_id,size_id,price) values(pid,(entry->>'size_id')::uuid,amount);
 end loop;
 if saved.is_pizza then
   update public.products set base_price=coalesce((select min(price) from public.product_size_prices where product_id=pid),0) where id=pid returning * into saved;
 end if;
 -- Force deferred checks before returning success to the caller.
 set constraints public.product_catalog_valid,public.product_price_catalog_valid,public.pizza_size_catalog_valid immediate;
 return saved;
end $$;
revoke all on function public.save_product_with_prices(uuid,uuid,jsonb,jsonb) from public,anon;
grant execute on function public.save_product_with_prices(uuid,uuid,jsonb,jsonb) to authenticated;
commit;
