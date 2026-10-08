-- Fix only product-images write isolation. Public SELECT and existing grants stay unchanged.
-- Replacement continues to use DELETE + INSERT; no UPDATE policy is introduced.
alter policy images_insert on storage.objects
  to authenticated
  with check (
    storage.objects.bucket_id = 'product-images'
    and storage.objects.name !~ '(^/|//|/$)'
    and storage.objects.name !~ '(^|/)\.{1,2}(/|$)'
    and position(chr(92) in storage.objects.name) = 0
    and exists (
      select 1 from public.stores as s
      where s.id::text = (storage.foldername(storage.objects.name))[1]
        and private.member_store(s.id)
    )
  );

alter policy images_delete on storage.objects
  to authenticated
  using (
    storage.objects.bucket_id = 'product-images'
    and storage.objects.name !~ '(^/|//|/$)'
    and storage.objects.name !~ '(^|/)\.{1,2}(/|$)'
    and position(chr(92) in storage.objects.name) = 0
    and exists (
      select 1 from public.stores as s
      where s.id::text = (storage.foldername(storage.objects.name))[1]
        and private.member_store(s.id)
    )
  );

