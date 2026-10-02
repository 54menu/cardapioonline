-- Structural baseline captured on 2026-09-30. No user data.
-- NEW empty Supabase projects only. Apply baseline and all migrations in one transaction.
-- Do not run this baseline on the existing production database.
create extension if not exists "uuid-ossp" with schema extensions;
set local search_path=public,extensions;
create table public."addon_groups" (
  "id" uuid default uuid_generate_v4() not null,
  "store_id" uuid not null,
  "name" text not null,
  "title" text not null,
  "type" text not null,
  "required" boolean default false not null,
  "applies_to" text[] default '{}'::text[],
  "display_order" integer default 1 not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
create table public."addon_options" (
  "id" uuid default uuid_generate_v4() not null,
  "group_id" uuid not null,
  "name" text not null,
  "price_diff" numeric default 0 not null,
  "allows_half_half" boolean default false not null,
  "is_default" boolean default false not null,
  "display_order" integer default 1 not null,
  "created_at" timestamp with time zone default now() not null
);
create table public."campaign_offers" (
  "campaign_id" uuid not null,
  "offer_id" uuid not null,
  "created_at" timestamp with time zone default now() not null
);
create table public."campaigns" (
  "id" uuid default uuid_generate_v4() not null,
  "store_id" uuid not null,
  "name" text not null,
  "description" text,
  "start_date" date not null,
  "end_date" date not null,
  "active" boolean default true not null,
  "display_order" integer default 1 not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
create table public."categories" (
  "id" uuid default uuid_generate_v4() not null,
  "store_id" uuid not null,
  "name" text not null,
  "display_order" integer default 1 not null,
  "is_active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "color" text,
  "price_label" text
);
create table public."invites" (
  "id" uuid default uuid_generate_v4() not null,
  "token" text default encode(gen_random_bytes(16), 'hex'::text) not null,
  "email" text not null,
  "created_by" uuid not null,
  "status" text default 'pending'::text not null,
  "accepted_by" uuid,
  "store_name" text,
  "store_slug" text,
  "expires_at" timestamp with time zone default (now() + '7 days'::interval) not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
create table public."neighborhoods" (
  "id" uuid default uuid_generate_v4() not null,
  "store_id" uuid not null,
  "name" text not null,
  "delivery_fee" numeric default 0 not null,
  "is_active" boolean default true not null,
  "display_order" integer default 1 not null,
  "created_at" timestamp with time zone default now() not null
);
create table public."offer_group_items" (
  "id" uuid default uuid_generate_v4() not null,
  "group_id" uuid not null,
  "product_id" uuid not null,
  "extra_price" numeric default 0 not null,
  "created_at" timestamp with time zone default now() not null
);
create table public."offer_groups" (
  "id" uuid default uuid_generate_v4() not null,
  "offer_id" uuid not null,
  "name" text not null,
  "quantity" integer not null,
  "display_order" integer default 1 not null,
  "created_at" timestamp with time zone default now() not null
);
create table public."offer_schedules" (
  "id" uuid default uuid_generate_v4() not null,
  "offer_id" uuid not null,
  "weekday" integer not null,
  "start_time" time without time zone not null,
  "end_time" time without time zone not null,
  "created_at" timestamp with time zone default now() not null
);
create table public."offers" (
  "id" uuid default uuid_generate_v4() not null,
  "store_id" uuid not null,
  "name" text not null,
  "description" text,
  "price" numeric not null,
  "active" boolean default true not null,
  "max_per_order" integer,
  "display_order" integer default 1 not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
create table public."orders" (
  "id" uuid default uuid_generate_v4() not null,
  "store_id" uuid not null,
  "order_number" text not null,
  "customer_name" text not null,
  "customer_phone" text not null,
  "customer_email" text,
  "customer_address" jsonb,
  "order_type" text not null,
  "items" jsonb not null,
  "subtotal" numeric not null,
  "delivery_fee" numeric default 0 not null,
  "discount" numeric default 0 not null,
  "total" numeric not null,
  "payment_method" text not null,
  "payment_status" text default 'pending'::text not null,
  "status" text default 'received'::text not null,
  "notes" text,
  "whatsapp_sent" boolean default false not null,
  "whatsapp_message_id" text,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "completed_at" timestamp with time zone
);
create table public."payments" (
  "id" uuid default uuid_generate_v4() not null,
  "store_id" uuid not null,
  "competence" text not null,
  "due_date" date not null,
  "grace_until" timestamp with time zone not null,
  "amount" numeric not null,
  "status" text default 'pending'::text not null,
  "mp_payment_id" text,
  "mp_status" text,
  "pix_qr" text,
  "pix_copy_paste" text,
  "paid_at" timestamp with time zone,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
create table public."pizza_sizes" (
  "id" uuid default uuid_generate_v4() not null,
  "store_id" uuid not null,
  "name" text not null,
  "slices" integer default 8 not null,
  "max_flavors" integer default 1 not null,
  "display_order" integer default 1 not null,
  "is_active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null
);
create table public."product_size_prices" (
  "product_id" uuid not null,
  "size_id" uuid not null,
  "price" numeric not null
);
create table public."products" (
  "id" uuid default uuid_generate_v4() not null,
  "store_id" uuid not null,
  "category_id" uuid not null,
  "name" text not null,
  "description" text,
  "base_price" numeric not null,
  "image_url" text,
  "is_pizza" boolean default false not null,
  "has_crusts" boolean default true not null,
  "has_extras" boolean default true not null,
  "available" boolean default true not null,
  "display_order" integer default 1 not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "codigo" integer,
  "is_featured" boolean default false not null,
  "featured_order" integer default 0 not null
);
create table public."profiles" (
  "id" uuid not null,
  "email" text not null,
  "full_name" text,
  "avatar_url" text,
  "role" text default 'owner'::text not null,
  "store_id" uuid,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
create table public."promotions" (
  "id" uuid default uuid_generate_v4() not null,
  "store_id" uuid not null,
  "title" text not null,
  "subtitle" text,
  "description" text,
  "price" numeric not null,
  "original_price" numeric,
  "badge" text,
  "image_url" text,
  "bg_color" text default '#ff6a00'::text,
  "text_color" text default '#ffffff'::text,
  "promo_type" text default 'hero'::text not null,
  "valid_days" text[] default '{0,1,2,3,4,5,6}'::integer[],
  "valid_from" time without time zone,
  "valid_until" time without time zone,
  "items" jsonb default '[]'::jsonb,
  "display_order" integer default 1 not null,
  "is_active" boolean default true not null,
  "is_featured" boolean default false not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
create table public."store_settings" (
  "store_id" uuid not null,
  "primary_color" text default '#e85d04'::text,
  "secondary_color" text default '#1a1a2e'::text,
  "font_family" text default 'Plus Jakarta Sans'::text,
  "accept_pix" boolean default true,
  "accept_card" boolean default true,
  "accept_cash" boolean default true,
  "allow_pickup" boolean default true,
  "allow_delivery" boolean default true,
  "min_order_delivery" numeric,
  "min_order_pickup" numeric,
  "schedule" jsonb,
  "whatsapp_business_number" text,
  "whatsapp_message_template" text,
  "notify_new_order_email" boolean default false,
  "notify_new_order_push" boolean default true,
  "meta_title" text,
  "meta_description" text,
  "social_image_url" text,
  "instagram_url" text,
  "facebook_url" text,
  "ga_measurement_id" text,
  "fb_pixel_id" text,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "fraction_pricing_mode" text default 'max'::text
);
create table public."stores" (
  "id" uuid default uuid_generate_v4() not null,
  "owner_id" uuid not null,
  "slug" text not null,
  "name" text not null,
  "phone" text not null,
  "phone_display" text,
  "description" text,
  "logo_url" text,
  "cover_url" text,
  "address" text,
  "opening_hours" text,
  "status" text default 'open'::text not null,
  "default_delivery_fee" numeric default 7.00,
  "min_order_value" numeric default 35.00,
  "settings" jsonb default '{}'::jsonb,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
create table public."subscriptions" (
  "store_id" uuid not null,
  "plan_amount" numeric default 29.00 not null,
  "status" text default 'trial'::text not null,
  "current_period_start" date,
  "current_period_end" date not null,
  "prepaid_until" date,
  "trial_ends_at" date,
  "pix_qr" text,
  "pix_copy_paste" text,
  "mp_payment_id" text,
  "last_payment_id" uuid,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
create table public."v_offers_full" (
  "id" uuid,
  "store_id" uuid,
  "name" text,
  "description" text,
  "price" numeric,
  "active" boolean,
  "max_per_order" integer,
  "display_order" integer,
  "created_at" timestamp with time zone,
  "updated_at" timestamp with time zone,
  "groups" json
);
create table public."v_recent_orders" (
  "id" uuid,
  "store_id" uuid,
  "order_number" text,
  "customer_name" text,
  "customer_phone" text,
  "customer_email" text,
  "customer_address" jsonb,
  "order_type" text,
  "items" jsonb,
  "subtotal" numeric,
  "delivery_fee" numeric,
  "discount" numeric,
  "total" numeric,
  "payment_method" text,
  "payment_status" text,
  "status" text,
  "notes" text,
  "whatsapp_sent" boolean,
  "whatsapp_message_id" text,
  "created_at" timestamp with time zone,
  "updated_at" timestamp with time zone,
  "completed_at" timestamp with time zone,
  "store_name" text,
  "store_slug" text
);
create table public."v_store_menu" (
  "store_id" uuid,
  "slug" text,
  "store_name" text,
  "phone" text,
  "logo_url" text,
  "cover_url" text,
  "default_delivery_fee" numeric,
  "min_order_value" numeric,
  "categories" json
);
alter table public."stores" add constraint "stores_status_check" CHECK ((status = ANY (ARRAY['open'::text, 'closed'::text])));
alter table public."stores" add constraint "stores_pkey" PRIMARY KEY (id);
alter table public."stores" add constraint "stores_slug_key" UNIQUE (slug);
alter table public."profiles" add constraint "profiles_pkey" PRIMARY KEY (id);
alter table public."categories" add constraint "categories_pkey" PRIMARY KEY (id);
alter table public."products" add constraint "products_pkey" PRIMARY KEY (id);
alter table public."addon_groups" add constraint "addon_groups_type_check" CHECK ((type = ANY (ARRAY['single'::text, 'multiple'::text])));
alter table public."addon_groups" add constraint "addon_groups_pkey" PRIMARY KEY (id);
alter table public."addon_options" add constraint "addon_options_pkey" PRIMARY KEY (id);
alter table public."neighborhoods" add constraint "neighborhoods_pkey" PRIMARY KEY (id);
alter table public."orders" add constraint "orders_order_type_check" CHECK ((order_type = ANY (ARRAY['delivery'::text, 'pickup'::text])));
alter table public."orders" add constraint "orders_payment_method_check" CHECK ((payment_method = ANY (ARRAY['pix'::text, 'card'::text, 'cash'::text, 'online'::text])));
alter table public."orders" add constraint "orders_payment_status_check" CHECK ((payment_status = ANY (ARRAY['pending'::text, 'paid'::text, 'failed'::text, 'refunded'::text])));
alter table public."orders" add constraint "orders_status_check" CHECK ((status = ANY (ARRAY['received'::text, 'preparing'::text, 'ready'::text, 'delivering'::text, 'delivered'::text, 'cancelled'::text])));
alter table public."orders" add constraint "orders_pkey" PRIMARY KEY (id);
alter table public."store_settings" add constraint "store_settings_pkey" PRIMARY KEY (store_id);
alter table public."products" add constraint "products_codigo_check" CHECK (((codigo >= 1) AND (codigo <= 999)));
alter table public."profiles" add constraint "profiles_role_check" CHECK ((role = ANY (ARRAY['superadmin'::text, 'owner'::text, 'staff'::text])));
alter table public."invites" add constraint "invites_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'expired'::text, 'revoked'::text])));
alter table public."invites" add constraint "invites_pkey" PRIMARY KEY (id);
alter table public."invites" add constraint "invites_token_key" UNIQUE (token);
alter table public."pizza_sizes" add constraint "pizza_sizes_max_flavors_check" CHECK (((max_flavors >= 1) AND (max_flavors <= 4)));
alter table public."pizza_sizes" add constraint "pizza_sizes_pkey" PRIMARY KEY (id);
alter table public."product_size_prices" add constraint "product_size_prices_price_check" CHECK ((price >= (0)::numeric));
alter table public."product_size_prices" add constraint "product_size_prices_pkey" PRIMARY KEY (product_id, size_id);
alter table public."promotions" add constraint "promotions_promo_type_check" CHECK ((promo_type = ANY (ARRAY['hero'::text, 'combo'::text, 'weekday'::text, 'bundle'::text])));
alter table public."promotions" add constraint "promotions_pkey" PRIMARY KEY (id);
alter table public."subscriptions" add constraint "subscriptions_status_check" CHECK ((status = ANY (ARRAY['trial'::text, 'active'::text, 'grace'::text, 'past_due'::text, 'blocked'::text, 'canceled'::text])));
alter table public."subscriptions" add constraint "subscriptions_pkey" PRIMARY KEY (store_id);
alter table public."payments" add constraint "payments_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'overdue'::text, 'canceled'::text])));
alter table public."payments" add constraint "payments_pkey" PRIMARY KEY (id);
alter table public."payments" add constraint "payments_store_id_competence_key" UNIQUE (store_id, competence);
alter table public."offers" add constraint "offers_price_check" CHECK ((price >= (0)::numeric));
alter table public."offers" add constraint "offers_max_per_order_check" CHECK (((max_per_order IS NULL) OR (max_per_order >= 1)));
alter table public."offers" add constraint "offers_pkey" PRIMARY KEY (id);
alter table public."offer_groups" add constraint "offer_groups_quantity_check" CHECK ((quantity >= 1));
alter table public."offer_groups" add constraint "offer_groups_pkey" PRIMARY KEY (id);
alter table public."offer_group_items" add constraint "offer_group_items_pkey" PRIMARY KEY (id);
alter table public."offer_group_items" add constraint "offer_group_items_group_id_product_id_key" UNIQUE (group_id, product_id);
alter table public."offer_schedules" add constraint "offer_schedules_weekday_check" CHECK (((weekday >= 0) AND (weekday <= 6)));
alter table public."offer_schedules" add constraint "offer_schedules_pkey" PRIMARY KEY (id);
alter table public."campaigns" add constraint "campaigns_check" CHECK ((end_date >= start_date));
alter table public."campaigns" add constraint "campaigns_pkey" PRIMARY KEY (id);
alter table public."campaign_offers" add constraint "campaign_offers_pkey" PRIMARY KEY (campaign_id, offer_id);
alter table public."store_settings" add constraint "store_settings_fraction_pricing_mode_check" CHECK ((fraction_pricing_mode = ANY (ARRAY['max'::text, 'proporcional'::text, 'proportional'::text])));
alter table public."product_size_prices" add constraint "product_size_prices_product_id_fkey" FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE;
alter table public."product_size_prices" add constraint "product_size_prices_size_id_fkey" FOREIGN KEY (size_id) REFERENCES pizza_sizes(id) ON DELETE CASCADE;
alter table public."stores" add constraint "stores_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public."profiles" add constraint "profiles_store_id_fkey" FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE SET NULL;
alter table public."categories" add constraint "categories_store_id_fkey" FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
alter table public."products" add constraint "products_store_id_fkey" FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
alter table public."products" add constraint "products_category_id_fkey" FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE RESTRICT;
alter table public."addon_groups" add constraint "addon_groups_store_id_fkey" FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
alter table public."addon_options" add constraint "addon_options_group_id_fkey" FOREIGN KEY (group_id) REFERENCES addon_groups(id) ON DELETE CASCADE;
alter table public."neighborhoods" add constraint "neighborhoods_store_id_fkey" FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
alter table public."orders" add constraint "orders_store_id_fkey" FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
alter table public."store_settings" add constraint "store_settings_store_id_fkey" FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
alter table public."invites" add constraint "invites_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public."invites" add constraint "invites_accepted_by_fkey" FOREIGN KEY (accepted_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public."pizza_sizes" add constraint "pizza_sizes_store_id_fkey" FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
alter table public."promotions" add constraint "promotions_store_id_fkey" FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
alter table public."subscriptions" add constraint "subscriptions_store_id_fkey" FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
alter table public."payments" add constraint "payments_store_id_fkey" FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
alter table public."campaign_offers" add constraint "campaign_offers_campaign_id_fkey" FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE;
alter table public."offers" add constraint "offers_store_id_fkey" FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
alter table public."offer_groups" add constraint "offer_groups_offer_id_fkey" FOREIGN KEY (offer_id) REFERENCES offers(id) ON DELETE CASCADE;
alter table public."offer_group_items" add constraint "offer_group_items_group_id_fkey" FOREIGN KEY (group_id) REFERENCES offer_groups(id) ON DELETE CASCADE;
alter table public."offer_group_items" add constraint "offer_group_items_product_id_fkey" FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE;
alter table public."offer_schedules" add constraint "offer_schedules_offer_id_fkey" FOREIGN KEY (offer_id) REFERENCES offers(id) ON DELETE CASCADE;
alter table public."campaigns" add constraint "campaigns_store_id_fkey" FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
alter table public."campaign_offers" add constraint "campaign_offers_offer_id_fkey" FOREIGN KEY (offer_id) REFERENCES offers(id) ON DELETE CASCADE;
CREATE OR REPLACE FUNCTION public.update_subscriptions_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin new.updated_at = now(); return new; end; $function$
;
CREATE OR REPLACE FUNCTION public.next_due_date(from_date date DEFAULT CURRENT_DATE)
 RETURNS date
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select (date_trunc('month', from_date::timestamp) + interval '1 month')::date
$function$
;
CREATE OR REPLACE FUNCTION public.ensure_subscription(p_store_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
declare v_due date; v_exists uuid;
begin
  select store_id into v_exists from public.subscriptions where store_id = p_store_id;
  if v_exists is not null then return v_exists; end if;
  v_due := public.next_due_date(current_date);
  insert into public.subscriptions (store_id, plan_amount, status, current_period_start, current_period_end, trial_ends_at)
  values (p_store_id, 29.00, 'trial', current_date, v_due, v_due)
  on conflict (store_id) do nothing;
  return p_store_id;
end; $function$
;
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.generate_order_number(p_store_id uuid)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
declare
  v_number text;
  v_count int;
begin
  select count(*) + 1 into v_count
  from public.orders
  where store_id = p_store_id
    and date_trunc('day', created_at) = date_trunc('day', now());
  v_number := 'PDV-' || to_char(now(), 'YYYYMMDD') || lpad(v_count::text, 3, '0');
  return v_number;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_invite RECORD; v_token TEXT; BEGIN v_token := new.raw_user_meta_data->>'invite_token'; INSERT INTO public.profiles (id,email,full_name,avatar_url,role) VALUES (new.id,new.email,new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'avatar_url','owner'); IF v_token IS NOT NULL THEN SELECT id,status,expires_at INTO v_invite FROM public.invites WHERE token=v_token; IF FOUND AND v_invite.status='pending' AND v_invite.expires_at > now() THEN UPDATE public.invites SET status='accepted',accepted_by=new.id,updated_at=now() WHERE id=v_invite.id; END IF; END IF; RETURN new; END; $function$
;
CREATE OR REPLACE FUNCTION public.is_superadmin()
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$ SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role='superadmin'); $function$
;
CREATE OR REPLACE FUNCTION public.validate_invite(p_token text)
 RETURNS TABLE(invite_id uuid, store_name text, store_slug text, is_valid boolean, invite_email text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_invite RECORD; BEGIN
 SELECT i.id,i.email,i.status,i.expires_at,i.store_name,i.store_slug INTO v_invite FROM public.invites i WHERE i.token=p_token;
 IF NOT FOUND THEN RETURN QUERY SELECT NULL::UUID,NULL::TEXT,NULL::TEXT,FALSE::BOOLEAN,NULL::TEXT; RETURN; END IF;
 IF v_invite.status!='pending' THEN RETURN QUERY SELECT v_invite.id,v_invite.store_name,v_invite.store_slug,FALSE::BOOLEAN,v_invite.email; RETURN; END IF;
 IF v_invite.expires_at < now() THEN UPDATE public.invites SET status='expired' WHERE id=v_invite.id; RETURN QUERY SELECT v_invite.id,v_invite.store_name,v_invite.store_slug,FALSE::BOOLEAN,v_invite.email; RETURN; END IF;
 RETURN QUERY SELECT v_invite.id,v_invite.store_name,v_invite.store_slug,TRUE::BOOLEAN,v_invite.email;
END; $function$
;
CREATE TRIGGER update_stores_updated_at BEFORE UPDATE ON public.stores FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON public.categories FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_addon_groups_updated_at BEFORE UPDATE ON public.addon_groups FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_store_settings_updated_at BEFORE UPDATE ON public.store_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();
CREATE TRIGGER update_invites_updated_at BEFORE UPDATE ON public.invites FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_promotions_updated_at BEFORE UPDATE ON public.promotions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON public.subscriptions FOR EACH ROW EXECUTE FUNCTION update_subscriptions_updated_at();
CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_offers_updated_at BEFORE UPDATE ON public.offers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_campaigns_updated_at BEFORE UPDATE ON public.campaigns FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE INDEX idx_subscriptions_status ON public.subscriptions USING btree (status);
CREATE INDEX idx_payments_store_competence ON public.payments USING btree (store_id, competence);
CREATE INDEX idx_payments_due ON public.payments USING btree (due_date, status);
CREATE INDEX idx_payments_grace ON public.payments USING btree (grace_until, status);
CREATE INDEX idx_offers_store ON public.offers USING btree (store_id);
CREATE INDEX idx_offers_store_active ON public.offers USING btree (store_id, active);
CREATE INDEX idx_offer_groups_offer ON public.offer_groups USING btree (offer_id);
CREATE INDEX idx_offer_group_items_group ON public.offer_group_items USING btree (group_id);
CREATE INDEX idx_offer_group_items_product ON public.offer_group_items USING btree (product_id);
CREATE INDEX idx_offer_schedules_offer ON public.offer_schedules USING btree (offer_id);
CREATE INDEX idx_campaigns_store ON public.campaigns USING btree (store_id);
CREATE INDEX idx_campaigns_store_active ON public.campaigns USING btree (store_id, active);
CREATE INDEX idx_campaign_offers_campaign ON public.campaign_offers USING btree (campaign_id);
CREATE INDEX idx_campaign_offers_offer ON public.campaign_offers USING btree (offer_id);
CREATE INDEX idx_orders_store ON public.orders USING btree (store_id);
CREATE INDEX idx_orders_store_created ON public.orders USING btree (store_id, created_at DESC);
CREATE INDEX idx_orders_store_status ON public.orders USING btree (store_id, status);
CREATE INDEX idx_orders_customer_phone ON public.orders USING btree (customer_phone);
CREATE INDEX idx_stores_owner ON public.stores USING btree (owner_id);
CREATE INDEX idx_stores_slug ON public.stores USING btree (slug);
CREATE INDEX idx_products_store ON public.products USING btree (store_id);
CREATE INDEX idx_products_category ON public.products USING btree (category_id);
CREATE INDEX idx_products_store_available ON public.products USING btree (store_id, available);
CREATE INDEX idx_products_store_category_order ON public.products USING btree (store_id, category_id, display_order);
CREATE INDEX idx_products_store_featured ON public.products USING btree (store_id, is_featured, featured_order, display_order) WHERE (is_featured = true);
CREATE INDEX idx_categories_store ON public.categories USING btree (store_id);
CREATE INDEX idx_categories_store_order ON public.categories USING btree (store_id, display_order);
CREATE INDEX idx_addon_groups_store ON public.addon_groups USING btree (store_id);
CREATE INDEX idx_addon_options_group ON public.addon_options USING btree (group_id);
CREATE INDEX idx_addon_options_group_order ON public.addon_options USING btree (group_id, display_order);
CREATE INDEX idx_neighborhoods_store ON public.neighborhoods USING btree (store_id);
CREATE INDEX idx_profiles_store ON public.profiles USING btree (store_id);
CREATE INDEX idx_invites_token ON public.invites USING btree (token);
CREATE INDEX idx_invites_email ON public.invites USING btree (email);
CREATE INDEX idx_invites_status ON public.invites USING btree (status);
CREATE INDEX idx_pizza_sizes_store ON public.pizza_sizes USING btree (store_id);
CREATE INDEX idx_pizza_sizes_store_order ON public.pizza_sizes USING btree (store_id, display_order);
CREATE INDEX idx_product_size_prices_product ON public.product_size_prices USING btree (product_id);
CREATE INDEX idx_product_size_prices_size ON public.product_size_prices USING btree (size_id);
CREATE INDEX idx_promotions_store ON public.promotions USING btree (store_id);
CREATE INDEX idx_promotions_store_active ON public.promotions USING btree (store_id, is_active, display_order);
CREATE INDEX idx_promotions_type ON public.promotions USING btree (promo_type);

CREATE VIEW public.v_offers_full WITH (security_invoker = true) AS
 SELECT o.id,
    o.store_id,
    o.name,
    o.description,
    o.price,
    o.active,
    o.max_per_order,
    o.display_order,
    o.created_at,
    o.updated_at,
    json_agg(DISTINCT jsonb_build_object('id', g.id, 'name', g.name, 'quantity', g.quantity)) AS groups
   FROM (offers o
     LEFT JOIN offer_groups g ON ((g.offer_id = o.id)))
  GROUP BY o.id;

CREATE VIEW public.v_store_menu WITH (security_invoker = true) AS
 SELECT s.id AS store_id,
    s.slug,
    s.name AS store_name,
    s.phone,
    s.logo_url,
    s.cover_url,
    s.default_delivery_fee,
    s.min_order_value,
    json_agg(json_build_object('id', c.id, 'name', c.name, 'order', c.display_order, 'products', ( SELECT json_agg(json_build_object('id', p.id, 'name', p.name, 'description', p.description, 'price', p.base_price, 'image', p.image_url, 'is_pizza', p.is_pizza, 'has_crusts', p.has_crusts, 'has_extras', p.has_extras, 'available', p.available, 'order', p.display_order) ORDER BY p.display_order) AS json_agg
           FROM products p
          WHERE ((p.category_id = c.id) AND (p.available = true)))) ORDER BY c.display_order) AS categories
   FROM (stores s
     LEFT JOIN categories c ON (((c.store_id = s.id) AND (c.is_active = true))))
  WHERE (s.status = 'open'::text)
  GROUP BY s.id, s.slug, s.name, s.phone, s.logo_url, s.cover_url, s.default_delivery_fee, s.min_order_value;

CREATE VIEW public.v_recent_orders WITH (security_invoker = true) AS
 SELECT o.id,
    o.store_id,
    o.order_number,
    o.customer_name,
    o.customer_phone,
    o.customer_email,
    o.customer_address,
    o.order_type,
    o.items,
    o.subtotal,
    o.delivery_fee,
    o.discount,
    o.total,
    o.payment_method,
    o.payment_status,
    o.status,
    o.notes,
    o.whatsapp_sent,
    o.whatsapp_message_id,
    o.created_at,
    o.updated_at,
    o.completed_at,
    s.name AS store_name,
    s.slug AS store_slug
   FROM (orders o
     JOIN stores s ON ((s.id = o.store_id)))
  WHERE (o.created_at > (now() - '30 days'::interval))
  ORDER BY o.created_at DESC;
