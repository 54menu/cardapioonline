-- Signup without an invite always creates an owner, never a privileged profile.
-- Preserve validation and single-use consumption when an invite is supplied.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path='' as $$
declare
 invitation public.invites%rowtype;
 signup_invite_token text := nullif(btrim(new.raw_user_meta_data->>'invite_token'), '');
begin
 if signup_invite_token is not null then
   select * into invitation from public.invites where token=signup_invite_token for update;
   if not found or invitation.status<>'pending' or invitation.expires_at<=now() or lower(invitation.email)<>lower(new.email) then
     raise exception 'A valid invitation for this email is required';
   end if;
 end if;
 insert into public.profiles(id,email,full_name,avatar_url,role)
 values(new.id,new.email,new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'avatar_url','owner');
 if signup_invite_token is not null then
   update public.invites set status='accepted',accepted_by=new.id,updated_at=now() where id=invitation.id;
 end if;
 return new;
end $$;
-- This trigger is internal, not a callable Data API endpoint.
revoke all on function public.handle_new_user() from public,anon,authenticated;
