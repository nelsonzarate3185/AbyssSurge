-- 002_hunters.sql
-- El jugador: perfil, progresión, energía, loadout y avance de historia.

-- ─────────────────────────────────────────────────────────────
-- hunters
-- Perfil de juego. 1:1 con auth.users.
-- ─────────────────────────────────────────────────────────────

create table hunters (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 20),
  class        hunter_class not null references class_archetypes (class),

  -- Progresión (PDF §6)
  rank         hunter_rank not null default 'E',
  exp          bigint not null default 0 check (exp >= 0),

  -- Economía del juego. Las gemas son moneda premium: ver 005_economy.sql
  gold         bigint not null default 0 check (gold    >= 0),
  essence      bigint not null default 0 check (essence >= 0),
  gems         bigint not null default 0 check (gems    >= 0),

  -- Energía: se materializa al gastarla y se regenera por tiempo entre gastos.
  -- El valor vigente NO es esta columna: es current_energy(). Ver 006_rpc.sql.
  energy            integer not null default 50 check (energy >= 0),
  energy_updated_at timestamptz not null default now(),

  -- Narrativa
  story_act     smallint not null default 1 check (story_act between 1 and 6),
  ending_chosen text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen  timestamptz not null default now()
);

create index hunters_rank_exp_idx on hunters (rank desc, exp desc);

comment on column hunters.energy is
  'Último valor materializado. La energía REAL es current_energy(id), que le '
  'suma la regeneración acumulada desde energy_updated_at. Leer esta columna '
  'directamente devuelve un valor viejo.';

-- ─────────────────────────────────────────────────────────────
-- hunter_powers
-- Poderes desbloqueados + loadout: 4 activos + 2 pasivos (PDF §7).
-- ─────────────────────────────────────────────────────────────

create table hunter_powers (
  hunter_id    uuid not null references hunters (id) on delete cascade,
  power_id     text not null references powers (id),
  unlocked_at  timestamptz not null default now(),

  -- 1–4 = slots activos, 5–6 = slots pasivos. NULL = desbloqueado sin equipar.
  loadout_slot smallint check (loadout_slot between 1 and 6),

  primary key (hunter_id, power_id)
);

-- Un slot no puede tener dos poderes.
create unique index hunter_powers_slot_idx
  on hunter_powers (hunter_id, loadout_slot)
  where loadout_slot is not null;

-- ─────────────────────────────────────────────────────────────
-- hunter_stats (vista)
-- Stats efectivos = base de la clase × multiplicador del rango.
-- El cliente nunca calcula esto por su cuenta.
-- ─────────────────────────────────────────────────────────────

create view hunter_stats
with (security_invoker = on) as
select
  h.id            as hunter_id,
  h.class,
  h.rank,
  h.exp,
  floor(c.base_hp  * r.stat_multiplier)::integer as hp,
  floor(c.base_atk * r.stat_multiplier)::integer as atk,
  floor(c.base_def * r.stat_multiplier)::integer as def,
  floor(c.base_vel * r.stat_multiplier)::integer as vel,
  r.aura_scale,
  r.aura_darkness
from hunters h
join class_archetypes c on c.class = h.class
join rank_tiers       r on r.rank  = h.rank;

comment on view hunter_stats is
  'Stats efectivos del cazador. security_invoker = on: hereda la RLS de hunters, '
  'así que cada jugador solo ve los suyos.';

-- ─────────────────────────────────────────────────────────────
-- story_progress
-- Un renglón por acto completado.
-- ─────────────────────────────────────────────────────────────

create table story_progress (
  hunter_id    uuid not null references hunters (id) on delete cascade,
  act          smallint not null check (act between 1 and 6),
  completed_at timestamptz not null default now(),
  primary key (hunter_id, act)
);

-- ─────────────────────────────────────────────────────────────
-- updated_at automático
-- ─────────────────────────────────────────────────────────────

create or replace function set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger hunters_set_updated_at
  before update on hunters
  for each row execute function set_updated_at();

-- ─────────────────────────────────────────────────────────────
-- RLS
-- ─────────────────────────────────────────────────────────────

alter table hunters        enable row level security;
alter table hunter_powers  enable row level security;
alter table story_progress enable row level security;

-- El cazador lee su perfil completo.
create policy "hunters: read own" on hunters
  for select using (auth.uid() = id);

-- Puede actualizar su propia fila; QUÉ columnas puede tocar lo decide el
-- GRANT del final de este archivo, no esta policy.
create policy "hunters: update own row" on hunters
  for update using (auth.uid() = id) with check (auth.uid() = id);

create policy "hunter_powers: read own" on hunter_powers
  for select using (auth.uid() = hunter_id);

-- Equipar/desequipar es del cliente; desbloquear no.
create policy "hunter_powers: manage own loadout" on hunter_powers
  for update using (auth.uid() = hunter_id) with check (auth.uid() = hunter_id);

create policy "story_progress: read own" on story_progress
  for select using (auth.uid() = hunter_id);

-- ─────────────────────────────────────────────────────────────
-- Grants por columna
--
-- IMPORTANTE: RLS filtra FILAS, no COLUMNAS. La policy de arriba deja al
-- cazador actualizar su propia fila… incluyendo `gold` y `gems`. Lo que
-- restringe las columnas es el GRANT, no la policy.
--
-- Supabase concede ALL sobre las tablas de `public` a `authenticated` por
-- default privileges, así que hay que revocar primero.
-- ─────────────────────────────────────────────────────────────

revoke all on table hunters        from anon, authenticated;
revoke all on table hunter_powers  from anon, authenticated;
revoke all on table story_progress from anon, authenticated;

grant select                    on table hunters to authenticated;
grant update (display_name)     on table hunters to authenticated;

grant select                    on table hunter_powers to authenticated;
grant update (loadout_slot)     on table hunter_powers to authenticated;

grant select                    on table story_progress to authenticated;

-- La vista no hereda los grants de las tablas: hay que concederla aparte.
grant select                    on hunter_stats to authenticated;

-- Nada de insert ni delete para el cliente en ninguna de las tres:
-- crear un cazador, desbloquear un poder o cerrar un acto pasa por RPC.
