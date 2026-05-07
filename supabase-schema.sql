-- ============================================================
--  TAPA NA LATA — Schema Supabase  (v2)
--  Execute no SQL Editor: supabase.com → projeto → SQL Editor
-- ============================================================

create extension if not exists "pgcrypto";

-- ── profiles ────────────────────────────────────────────────
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  name       text not null,
  phone      text default '',
  role       text not null default 'client' check (role in ('client','admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ── services ────────────────────────────────────────────────
create table if not exists public.services (
  id          uuid primary key default gen_random_uuid(),
  name        text    not null,
  description text    default '',
  price       integer not null default 0,
  duration    integer not null default 60,
  icon        text    default '🔧',
  active      boolean not null default true,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ── addons ──────────────────────────────────────────────────
create table if not exists public.addons (
  id          uuid primary key default gen_random_uuid(),
  name        text    not null,
  price       integer not null default 0,
  duration    integer not null default 15,
  icon        text    default '✨',
  active      boolean not null default true,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ── appointments ────────────────────────────────────────────
create table if not exists public.appointments (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  client_name    text not null,
  client_email   text not null,
  client_phone   text default '',
  plate          text not null,
  model          text not null,
  color          text default '',
  service_ids    uuid[]  not null default '{}',
  service_names  text[]  not null default '{}',
  addon_ids      uuid[]  not null default '{}',
  addon_names    text[]  not null default '{}',
  date           date    not null,
  time           text    not null,
  status         text    not null default 'Pendente'
                   check (status in ('Pendente','Confirmado','Em Andamento','Finalização','Finalizado','Cancelado')),
  total          integer not null default 0,
  notes          text    default '',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- ── notifications ────────────────────────────────────────────
create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  type       text not null default 'booking',
  title      text not null,
  body       text default '',
  read       boolean not null default false,
  created_at timestamptz not null default now()
);

-- ── blocked_slots ────────────────────────────────────────────
create table if not exists public.blocked_slots (
  id         uuid primary key default gen_random_uuid(),
  date       date,
  time       text,
  reason     text default '',
  created_at timestamptz not null default now()
);

-- ============================================================
--  ROW LEVEL SECURITY
-- ============================================================
alter table public.profiles       enable row level security;
alter table public.services       enable row level security;
alter table public.addons         enable row level security;
alter table public.appointments   enable row level security;
alter table public.notifications  enable row level security;
alter table public.blocked_slots  enable row level security;

-- profiles
create policy "Próprio perfil" on public.profiles for select using (auth.uid() = id);
create policy "Atualizar próprio perfil" on public.profiles for update using (auth.uid() = id);
create policy "Admin vê todos" on public.profiles for select
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

-- services / addons — leitura para todos autenticados, escrita só admin
create policy "Lê serviços" on public.services for select using (auth.role() = 'authenticated');
create policy "Admin gerencia serviços" on public.services for all
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

create policy "Lê adicionais" on public.addons for select using (auth.role() = 'authenticated');
create policy "Admin gerencia adicionais" on public.addons for all
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

-- appointments
create policy "Cliente vê próprios" on public.appointments for select using (auth.uid() = user_id);
create policy "Cliente cria" on public.appointments for insert with check (auth.uid() = user_id);
create policy "Cliente cancela" on public.appointments for update
  using (auth.uid() = user_id)
  with check (status = 'Cancelado');
create policy "Admin vê todos apts" on public.appointments for select
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));
create policy "Admin atualiza" on public.appointments for update
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

-- notifications
create policy "Lê próprias notifs" on public.notifications for select using (auth.uid() = user_id);
create policy "Atualiza próprias notifs" on public.notifications for update using (auth.uid() = user_id);
create policy "Cria notifs" on public.notifications for insert with check (auth.uid() = user_id);
create policy "Admin cria notifs" on public.notifications for insert
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

-- blocked_slots — leitura para todos, escrita só admin
create policy "Lê bloqueios" on public.blocked_slots for select using (auth.role() = 'authenticated');
create policy "Admin gerencia bloqueios" on public.blocked_slots for all
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

-- ============================================================
--  TRIGGERS
-- ============================================================
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

create trigger trg_profiles_upd   before update on public.profiles   for each row execute procedure public.set_updated_at();
create trigger trg_services_upd   before update on public.services   for each row execute procedure public.set_updated_at();
create trigger trg_addons_upd     before update on public.addons     for each row execute procedure public.set_updated_at();
create trigger trg_apts_upd       before update on public.appointments for each row execute procedure public.set_updated_at();

-- Cria perfil automaticamente ao registrar novo usuário
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, name, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    'client'
  );
  return new;
end; $$;

drop trigger if exists trg_on_auth_user_created on auth.users;
create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
--  SEED: Serviços e Adicionais iniciais
-- ============================================================
insert into public.services (name, description, price, duration, icon, active, sort_order) values
  ('Lavagem Detalhada',     'Limpeza completa com produtos profissionais',                 80,  60,  '🚿', true, 1),
  ('Polimento Técnico',     'Restauração do brilho, remove arranhões superficiais',        350, 180, '✨', true, 2),
  ('Higienização Interna',  'Limpeza profunda: bancos, tapetes, ar-condicionado',          220, 120, '🧹', true, 3),
  ('Descontaminação',       'Remove impurezas ferrosas e orgânicas da pintura',            180, 90,  '⚗️', true, 4),
  ('Restauração de Faróis', 'Clareza e segurança — faróis novos sem trocar',              150, 60,  '💡', true, 5),
  ('Vitrificação 9H',       'Proteção premium de longa duração para a pintura',            400, 240, '🛡️', true, 6),
  ('Cristalização de Vidros','Melhora visibilidade e repele água',                         120, 45,  '🔷', true, 7),
  ('Martelinho de Ouro',    'Reparo de amassados sem necessidade de pintura',              280, 150, '🔨', false,8)
on conflict do nothing;

insert into public.addons (name, price, duration, icon, active, sort_order) values
  ('Aromatizante',               25,  5,  '🌿', true, 1),
  ('Cera Premium',               60,  30, '💎', true, 2),
  ('Revitalizador de Plásticos', 40,  20, '♻️', true, 3),
  ('Limpeza de Motor',           90,  45, '⚙️', true, 4),
  ('Impermeabilização',         130,  60, '🌧️', true, 5),
  ('Hidratação de Couro',        75,  30, '🪑', true, 6)
on conflict do nothing;

-- ============================================================
--  CONTA ADMIN
--  1. Vá em Authentication > Users > Add user
--     E-mail: admin@tapanalata.com  Senha: Admin#Lata2025
--     Marque "Auto Confirm User"
--  2. Copie o UUID do usuário criado e rode:
--     UPDATE public.profiles SET role = 'admin' WHERE id = 'COLE-UUID-AQUI';
-- ============================================================
