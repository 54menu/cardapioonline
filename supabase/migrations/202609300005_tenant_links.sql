begin;
create unique index if not exists categories_id_store_key on public.categories(id,store_id);
alter table public.products add constraint products_category_store_fk foreign key(category_id,store_id) references public.categories(id,store_id);
-- Policies allow reading the public catalog, but catalog editing must remain in the same store.
create or replace function private.guard_store_owner() returns trigger
language plpgsql set search_path='' as $$
begin
 if auth.role() in ('anon','authenticated') and new.owner_id is distinct from old.owner_id then
  raise exception 'Store ownership cannot be changed through the client' using errcode='42501';
 end if;
 return new;
end $$;
create trigger protect_store_owner before update on public.stores for each row execute function private.guard_store_owner();
commit;
