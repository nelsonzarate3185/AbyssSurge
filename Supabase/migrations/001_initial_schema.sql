-- 001_initial_schema.sql
-- Schema base de AbyssSurge: jugadores, runs, seeds diarias y naufragios.
-- Toda tabla se crea con RLS habilitado; las policies van en 002.

create extension if not exists "pgcrypto";

-- ─────────────────────────────────────────────────────────────
-- Enums
-- ─────────────────────────────────────────────────────────────

create type run_outcome as enum ('ascended', 'drowned', 'crushed', 'abandoned');
create type board_slot  as enum ('hull', 'regulator', 'keel', 'collector');
create type surger_class as enum ('diver', 'ballast', 'needle', 'scavenger');

-- ─────────────────────────────────────────────────────────────
-- players
-- Perfil de juego. 1:1 con auth.users.
-- ─────────────────────────────────────────────────────────────

create table players (
  id            uuid primary key references auth.users (id) on delete cascade,
  display_name  text not null check (char_length(display_name) between 2 and 24),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  -- Meta-progresión (ver GAME_MECHANICS.md §5)
  corruption    smallint not null default 0 check (corruption between 0 and 100),
  cores         bigint   not null default 0 check (cores >= 0),
  scrap         bigint   not null default 0 check (scrap >= 0),
  anchor_credit bigint   not null default 0 check (anchor_credit >= 0),

  -- Récords
  deepest_meters integer not null default 0 check (deepest_meters >= 0),
  runs_completed integer not null default 0 check (runs_completed >= 0)
);

create index players_deepest_idx on players (deepest_meters desc);

-- ─────────────────────────────────────────────────────────────
-- board_upgrades
-- Nivel por slot de la tabla del jugador.
-- ─────────────────────────────────────────────────────────────

create table board_upgrades (
  player_id  uuid not null references players (id) on delete cascade,
  slot       board_slot not null,
  level      smallint not null default 0 check (level between 0 and 10),
  updated_at timestamptz not null default now(),
  primary key (player_id, slot)
);

-- ─────────────────────────────────────────────────────────────
-- daily_seeds
-- Una run compartida por día. El servidor es dueño de la seed.
-- ─────────────────────────────────────────────────────────────

create table daily_seeds (
  seed_date  date primary key,
  seed       text not null,
  modifiers  jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────
-- runs
-- Resultado validado de un descenso. Insertadas SOLO por Edge Function.
-- ─────────────────────────────────────────────────────────────

create table runs (
  id              uuid primary key default gen_random_uuid(),
  player_id       uuid not null references players (id) on delete cascade,
  seed_date       date references daily_seeds (seed_date),
  seed            text not null,
  class           surger_class not null,

  depth_meters    integer not null check (depth_meters >= 0),
  cores_collected integer not null default 0 check (cores_collected >= 0),
  scrap_collected integer not null default 0 check (scrap_collected >= 0),
  duration_ms     integer not null check (duration_ms > 0),
  outcome         run_outcome not null,

  -- Solo las runs con outcome = 'ascended' acreditan botín (GAME_MECHANICS.md §2)
  credited        boolean not null default false,
  corruption_gain smallint not null default 0 check (corruption_gain >= 0),

  started_at      timestamptz not null,
  created_at      timestamptz not null default now()
);

create index runs_player_idx      on runs (player_id, created_at desc);
create index runs_daily_board_idx on runs (seed_date, depth_meters desc)
  where credited;

-- Un solo intento por jugador en la seed diaria.
create unique index runs_daily_one_attempt_idx on runs (player_id, seed_date)
  where seed_date is not null;

-- ─────────────────────────────────────────────────────────────
-- wrecks
-- Donde un jugador murió queda su tabla, recuperable por otro.
-- ─────────────────────────────────────────────────────────────

create table wrecks (
  id            uuid primary key default gen_random_uuid(),
  run_id        uuid not null unique references runs (id) on delete cascade,
  player_id     uuid not null references players (id) on delete cascade,
  seed          text not null,
  depth_meters  integer not null check (depth_meters >= 0),
  cores_lost    integer not null check (cores_lost >= 0),

  recovered_by  uuid references players (id) on delete set null,
  recovered_at  timestamptz,
  created_at    timestamptz not null default now(),

  constraint wrecks_no_self_recovery check (recovered_by is null or recovered_by <> player_id),
  constraint wrecks_recovery_consistent check (
    (recovered_by is null and recovered_at is null) or
    (recovered_by is not null and recovered_at is not null)
  )
);

create index wrecks_open_idx on wrecks (seed, depth_meters)
  where recovered_by is null;

-- ─────────────────────────────────────────────────────────────
-- quotas
-- Cuota del Consorcio. Presión narrativa como sistema (§7).
-- ─────────────────────────────────────────────────────────────

create table quotas (
  id            uuid primary key default gen_random_uuid(),
  player_id     uuid not null references players (id) on delete cascade,
  week_start    date not null,
  cores_required integer not null check (cores_required > 0),
  cores_delivered integer not null default 0 check (cores_delivered >= 0),
  settled       boolean not null default false,
  created_at    timestamptz not null default now(),
  unique (player_id, week_start)
);

-- ─────────────────────────────────────────────────────────────
-- updated_at automático
-- ─────────────────────────────────────────────────────────────

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger players_set_updated_at
  before update on players
  for each row execute function set_updated_at();

create trigger board_upgrades_set_updated_at
  before update on board_upgrades
  for each row execute function set_updated_at();

-- ─────────────────────────────────────────────────────────────
-- RLS: encendido en todas las tablas. Policies en 002.
-- ─────────────────────────────────────────────────────────────

alter table players        enable row level security;
alter table board_upgrades enable row level security;
alter table daily_seeds    enable row level security;
alter table runs           enable row level security;
alter table wrecks         enable row level security;
alter table quotas         enable row level security;
