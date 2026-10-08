begin;
-- Additive phase: validates only this RPC. Direct writes require the operational maintenance gate.
create or replace function public.save_product_with_prices(p_store_id uuid,p_product_id uuid,p_product jsonb,p_prices jsonb)
returns public.products language plpgsql security invoker set search_path='' as $$
declare saved public.products; entry jsonb; pid uuid:=coalesce(p_product_id,gen_random_uuid()); amount numeric;
begin
 if auth.uid() is null or not private.member_store(p_store_id) then
   raise exception 'Loja não autorizada' using errcode='42501';
 end if;
 if jsonb_typeof(p_product) is distinct from 'object' or jsonb_typeof(p_prices) is distinct from 'array' then
   raise exception 'Cadastro inválido' using errcode='22023';
 end if;
 if jsonb_array_length(p_prices)>100 then raise exception 'Quantidade de tamanhos inválida'; end if;
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
   if not exists(select 1 from public.pizza_sizes where id=(entry->>'size_id')::uuid and store_id=p_store_id) then
     raise exception 'Tamanho não pertence à loja' using errcode='23514';
   end if;
   amount:=(entry->>'price')::numeric;
   if amount<=0 or amount>99999999.99 or amount<>round(amount,2) then raise exception 'Preço inválido'; end if;
   insert into public.product_size_prices(product_id,size_id,price) values(pid,(entry->>'size_id')::uuid,amount);
 end loop;
 if saved.is_pizza then
   update public.products set base_price=coalesce((select min(price) from public.product_size_prices where product_id=pid),0) where id=pid returning * into saved;
 end if;
 -- Explicit final validation: no dependency on enforcement triggers.
 if saved.is_pizza and saved.available and not exists(
   select 1 from public.product_size_prices v join public.pizza_sizes s on s.id=v.size_id
   where v.product_id=pid and s.store_id=p_store_id and s.is_active and v.price>0 and v.price::text not in ('NaN','Infinity','-Infinity')
 ) then raise exception 'Pizza disponível precisa de pelo menos um tamanho ativo com preço válido' using errcode='23514'; end if;
 return saved;
end $$;
revoke all on function public.save_product_with_prices(uuid,uuid,jsonb,jsonb) from public,anon;
grant execute on function public.save_product_with_prices(uuid,uuid,jsonb,jsonb) to authenticated;
commit;
