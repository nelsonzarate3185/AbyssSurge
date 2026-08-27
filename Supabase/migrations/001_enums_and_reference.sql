-- 001_enums_and_reference.sql
-- Enums y tablas de referencia de Abyss Surge.
-- Fuente de diseño: Docs/Abyss_Surge_Trama_y_Personajes.pdf
--
-- Las tablas de referencia son de solo lectura para el cliente: definen las
-- reglas del juego, no el estado del jugador. Se pueblan desde seeds/.

create extension if not exists "pgcrypto";

-- ─────────────────────────────────────────────────────────────
-- Enums
-- ─────────────────────────────────────────────────────────────

create type hunter_class as enum (
  'dark_slayer',
  'phantom_guard',
  'abyss_mage',
  'beast_hunter'
);

-- ORDEN SIGNIFICATIVO: Postgres compara enums por orden de declaración,
-- así que `rank >= 'B'` funciona. No reordenar ni insertar en el medio.
create type hunter_rank as enum ('E', 'D', 'C', 'B', 'A', 'S', 'SS', 'SSS');

create type dungeon_type       as enum ('story', 'grind', 'awakening', 'clan');
create type dungeon_difficulty as enum ('normal', 'hard', 'impossible');
create type run_outcome        as enum ('cleared', 'failed', 'abandoned');

create type power_kind     as enum ('active', 'passive');
create type power_category as enum ('magic', 'defense', 'summon', 'control');

create type clan_role  as enum ('leader', 'captain', 'officer', 'member');
create type war_status as enum ('scheduled', 'active', 'ended');

-- ─────────────────────────────────────────────────────────────
-- class_archetypes
-- Stats base de las 4 clases. Valores exactos del PDF §3.
-- ─────────────────────────────────────────────────────────────

create table class_archetypes (
  class      hunter_class primary key,
  label      text not null,
  base_hp    integer not null check (base_hp  > 0),
  base_atk   integer not null check (base_atk > 0),
  base_def   integer not null check (base_def > 0),
  base_vel   integer not null check (base_vel > 0),
  strength   text not null,
  weakness   text not null
);

comment on table class_archetypes is
  'Arquetipos jugables. Stats base tal cual el PDF de diseño §3.';

-- ─────────────────────────────────────────────────────────────
-- rank_tiers
-- Progresión E → SSS. Cada rango sube stats y desbloquea mazmorras.
-- ─────────────────────────────────────────────────────────────

create table rank_tiers (
  rank            hunter_rank primary key,
  tier            smallint not null unique check (tier between 1 and 8),
  exp_required    bigint not null check (exp_required >= 0),
  stat_multiplier numeric(4,2) not null check (stat_multiplier >= 1.0),

  -- El aura crece y se oscurece con el rango (PDF §6). El cliente la resuelve
  -- con estos dos números, sin lógica propia.
  aura_scale      numeric(3,2) not null default 1.0,
  aura_darkness   numeric(3,2) not null default 0.0
                  check (aura_darkness between 0 and 1)
);

comment on column rank_tiers.exp_required is
  'EXP acumulada total para alcanzar este rango, no incremental. [TUNE]';

-- ─────────────────────────────────────────────────────────────
-- powers
-- Catálogo de poderes. Los poderes EVOLUCIONAN (no suben de nivel):
-- cada evolución es una fila distinta que apunta a la anterior.
-- ─────────────────────────────────────────────────────────────

create table powers (
  id            text primary key,
  class         hunter_class not null references class_archetypes (class),
  name          text not null,
  kind          power_kind not null default 'active',
  category      power_category not null,

  tier          smallint not null check (tier between 1 and 4),
  evolves_from  text references powers (id),

  damage_multiplier numeric(4,2) not null default 1.0,
  is_aoe        boolean not null default false,
  is_crit       boolean not null default false,
  is_summon     boolean not null default false,

  -- Costo de evolución (PDF §6: desafíos especiales + esencia + oro)
  essence_cost  integer not null default 0 check (essence_cost >= 0),
  gold_cost     integer not null default 0 check (gold_cost >= 0),
  challenge_id  text,

  min_rank      hunter_rank not null default 'E',

  -- El tier 1 no evoluciona de nada; los demás sí.
  constraint powers_evolution_chain check (
    (tier = 1 and evolves_from is null) or
    (tier > 1 and evolves_from is not null)
  )
);

create index powers_class_tier_idx on powers (class, tier);

comment on table powers is
  'Catálogo de poderes. La cadena del Dark Slayer viene del PDF §6; las de las '
  'otras 3 clases están pendientes de diseño.';

-- ─────────────────────────────────────────────────────────────
-- dungeons
-- Catálogo. Estructura fija: 3 pisos + 1 jefe (PDF §6).
-- ─────────────────────────────────────────────────────────────

create table dungeons (
  id           text primary key,
  name         text not null,
  type         dungeon_type not null,
  min_rank     hunter_rank not null default 'E',

  floors       smallint not null default 3 check (floors > 0),
  has_boss     boolean not null default true,
  energy_cost  smallint not null default 10 check (energy_cost >= 0),

  -- Recompensas base; la dificultad las multiplica (ver difficulty_modifiers)
  base_exp     integer not null default 0 check (base_exp     >= 0),
  base_gold    integer not null default 0 check (base_gold    >= 0),
  base_essence integer not null default 0 check (base_essence >= 0),

  story_act    smallint check (story_act between 1 and 6),
  sort_order   integer not null default 0,

  -- Solo las mazmorras de historia pertenecen a un acto.
  constraint dungeons_story_act_consistent check (
    (type = 'story' and story_act is not null) or
    (type <> 'story' and story_act is null)
  )
);

create index dungeons_type_rank_idx on dungeons (type, min_rank);

-- ─────────────────────────────────────────────────────────────
-- difficulty_modifiers
-- Normal / Hard / Imposible (PDF §6).
-- ─────────────────────────────────────────────────────────────

create table difficulty_modifiers (
  difficulty        dungeon_difficulty primary key,
  enemy_multiplier  numeric(4,2) not null check (enemy_multiplier  > 0),
  reward_multiplier numeric(4,2) not null check (reward_multiplier > 0),
  min_rank          hunter_rank not null default 'E'
);

-- ─────────────────────────────────────────────────────────────
-- Las tablas de referencia son públicas para usuarios autenticados.
-- ─────────────────────────────────────────────────────────────

alter table class_archetypes     enable row level security;
alter table rank_tiers           enable row level security;
alter table powers               enable row level security;
alter table dungeons             enable row level security;
alter table difficulty_modifiers enable row level security;

create policy "class_archetypes: read" on class_archetypes
  for select to authenticated using (true);
create policy "rank_tiers: read" on rank_tiers
  for select to authenticated using (true);
create policy "powers: read" on powers
  for select to authenticated using (true);
create policy "dungeons: read" on dungeons
  for select to authenticated using (true);
create policy "difficulty_modifiers: read" on difficulty_modifiers
  for select to authenticated using (true);

-- ─────────────────────────────────────────────────────────────
-- game_settings
-- Constantes de balance tuneables sin migration (energía máxima, ritmo de
-- regeneración, ventana de Clan Wars). Se leen con setting_int().
-- ─────────────────────────────────────────────────────────────

create table game_settings (
  key         text primary key,
  value       jsonb not null,
  description text
);

create or replace function setting_int(p_key text, p_default integer)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select (value #>> '{}')::integer from game_settings where key = p_key),
                  p_default);
$$;

alter table game_settings enable row level security;

create policy "game_settings: read" on game_settings
  for select to authenticated using (true);

revoke all on function setting_int(text, integer) from public;
grant execute on function setting_int(text, integer) to authenticated, service_role;
