-- Car Price Check : base de données Supabase
-- À coller une seule fois dans Supabase > SQL Editor > New query, puis "Run".
-- Principe de sécurité :
--   * les visiteurs anonymes peuvent seulement AJOUTER des lignes (jamais lire, modifier ou supprimer) ;
--   * seuls les comptes inscrits dans la table "admins" peuvent lire et gérer les données ;
--   * les documents déposés vont dans un espace privé "documents", lisible uniquement par les admins.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Administrateurs du tableau de bord
-- ---------------------------------------------------------------------------
create table if not exists public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admins enable row level security;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

drop policy if exists "admins read own row" on public.admins;
create policy "admins read own row" on public.admins
  for select to authenticated using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 1. Simulations : chaque clic sur "Calculer mon tarif" (aucune donnée personnelle)
-- ---------------------------------------------------------------------------
create table if not exists public.simulations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  visitor_id uuid,                          -- identifiant aléatoire de la visite (non stocké sur l'appareil), sans lien avec une personne
  brand text not null check (char_length(brand) between 1 and 60),
  model text not null check (char_length(model) between 1 and 120),
  province text not null check (char_length(province) between 1 and 60),
  net_price numeric(10,2) not null check (net_price > 0 and net_price < 1000000),
  list_price numeric(10,2) check (list_price is null or (list_price > 0 and list_price < 1000000)),
  trade_in boolean not null default false,
  market_mean numeric(10,2),
  share_below numeric(5,4) check (share_below is null or share_below between 0 and 1),
  verdict text check (verdict in ('good', 'mid', 'bad')),
  discount_pct numeric(5,2),
  market_source text not null default 'exemple' check (market_source in ('exemple', 'reel')),
  referrer text check (referrer is null or char_length(referrer) <= 300),
  utm text check (utm is null or char_length(utm) <= 300)
);

-- ---------------------------------------------------------------------------
-- 2. Partages : offre ou facture déposée par un acheteur
-- ---------------------------------------------------------------------------
create table if not exists public.shares (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  simulation_id uuid references public.simulations (id) on delete set null,
  kind text not null check (kind in ('offer', 'invoice')),
  email text not null check (char_length(email) between 5 and 200 and email like '%_@_%._%'),
  file_path text check (file_path is null or char_length(file_path) <= 300),
  file_name text check (file_name is null or char_length(file_name) <= 200),
  consent_stats boolean not null check (consent_stats),
  consent_results boolean not null default false,
  consent_text_version text not null check (char_length(consent_text_version) <= 40),
  status text not null default 'nouveau' check (status in ('nouveau', 'lu', 'analyse_envoyee', 'rejete')),
  document_deleted_at timestamptz,
  admin_note text
);

-- ---------------------------------------------------------------------------
-- 3. Leads courtiers
-- ---------------------------------------------------------------------------
create table if not exists public.broker_leads (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  simulation_id uuid references public.simulations (id) on delete set null,
  province text check (province is null or char_length(province) <= 60),
  car text check (car is null or char_length(car) <= 200),
  contact_pref text not null check (contact_pref in ('tel', 'mail')),
  phone text check (phone is null or char_length(phone) between 6 and 30),
  email text check (email is null or (char_length(email) between 5 and 200 and email like '%_@_%._%')),
  consent boolean not null check (consent),
  consent_text_version text not null check (char_length(consent_text_version) <= 40),
  status text not null default 'nouveau' check (status in ('nouveau', 'transmis', 'contacte', 'converti', 'perdu')),
  broker text,
  admin_note text,
  check ((contact_pref = 'tel' and phone is not null) or (contact_pref = 'mail' and email is not null))
);

-- ---------------------------------------------------------------------------
-- 4. Leads marques (offres d'autres constructeurs)
-- ---------------------------------------------------------------------------
create table if not exists public.brand_leads (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  simulation_id uuid references public.simulations (id) on delete set null,
  brands text[] not null check (array_length(brands, 1) between 1 and 20),
  email text not null check (char_length(email) between 5 and 200 and email like '%_@_%._%'),
  car text check (car is null or char_length(car) <= 200),
  province text check (province is null or char_length(province) <= 60),
  net_price numeric(10,2),
  consent boolean not null check (consent),
  consent_text_version text not null check (char_length(consent_text_version) <= 40),
  status text not null default 'nouveau' check (status in ('nouveau', 'transmis', 'perdu')),
  admin_note text
);

create index if not exists simulations_created_idx on public.simulations (created_at desc);
create index if not exists shares_created_idx on public.shares (created_at desc);
create index if not exists broker_leads_created_idx on public.broker_leads (created_at desc);
create index if not exists brand_leads_created_idx on public.brand_leads (created_at desc);

-- ---------------------------------------------------------------------------
-- Règles d'accès (Row Level Security)
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['simulations', 'shares', 'broker_leads', 'brand_leads'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "public insert" on public.%I', t);
    execute format('create policy "public insert" on public.%I for insert to anon, authenticated with check (true)', t);
    execute format('drop policy if exists "admin read" on public.%I', t);
    execute format('create policy "admin read" on public.%I for select to authenticated using (public.is_admin())', t);
    execute format('drop policy if exists "admin update" on public.%I', t);
    execute format('create policy "admin update" on public.%I for update to authenticated using (public.is_admin()) with check (public.is_admin())', t);
    execute format('drop policy if exists "admin delete" on public.%I', t);
    execute format('create policy "admin delete" on public.%I for delete to authenticated using (public.is_admin())', t);
  end loop;
end $$;

-- Les nouvelles lignes publiques gardent toujours leur statut par défaut.
create or replace function public.force_new_status()
returns trigger language plpgsql as $$
begin
  if not public.is_admin() then
    new.status := 'nouveau';
    new.admin_note := null;
    new.created_at := now();
  end if;
  return new;
end $$;

drop trigger if exists shares_status on public.shares;
create trigger shares_status before insert on public.shares for each row execute function public.force_new_status();
drop trigger if exists broker_status on public.broker_leads;
create trigger broker_status before insert on public.broker_leads for each row execute function public.force_new_status();
drop trigger if exists brand_status on public.brand_leads;
create trigger brand_status before insert on public.brand_leads for each row execute function public.force_new_status();

create or replace function public.force_now()
returns trigger language plpgsql as $$
begin
  if not public.is_admin() then new.created_at := now(); end if;
  return new;
end $$;
drop trigger if exists simulations_now on public.simulations;
create trigger simulations_now before insert on public.simulations for each row execute function public.force_now();

-- ---------------------------------------------------------------------------
-- Espace de stockage privé pour les documents (10 Mo max, PDF et images)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documents', 'documents', false, 10485760,
        array['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "public upload documents" on storage.objects;
create policy "public upload documents" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'documents' and (storage.foldername(name))[1] = 'uploads');

drop policy if exists "admin read documents" on storage.objects;
create policy "admin read documents" on storage.objects
  for select to authenticated using (bucket_id = 'documents' and public.is_admin());

drop policy if exists "admin delete documents" on storage.objects;
create policy "admin delete documents" on storage.objects
  for delete to authenticated using (bucket_id = 'documents' and public.is_admin());

-- ---------------------------------------------------------------------------
-- Dernière étape (à faire APRÈS avoir créé votre compte dans Authentication > Users) :
-- remplacez l'adresse ci-dessous par la vôtre et exécutez cette ligne seule.
--
-- insert into public.admins (user_id)
-- select id from auth.users where email = 'votre-adresse@exemple.be';
-- ---------------------------------------------------------------------------
