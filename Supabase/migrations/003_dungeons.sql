-- 003_dungeons.sql
-- Intentos de mazmorra. El cliente NO inserta acá: la Edge Function
-- `complete-dungeon-run` es la única que acredita recompensas.

create table dungeon_runs (
  id          uuid primary key default gen_random_uuid(),
  hunter_id   uuid not null references hunters (id) on delete cascade,
  dungeon_id  text not null references dungeons (id),
  difficulty  dungeon_difficulty not null default 'normal',

  -- Rango del cazador al entrar. Se congela: sirve para auditar recompensas
  -- viejas aunque después suba de rango.
  rank_at_entry hunter_rank not null,

  floors_cleared smallint not null default 0 check (floors_cleared >= 0),
  boss_defeated  boolean  not null default false,
  outcome        run_outcome not null,

  exp_awarded     integer not null default 0 check (exp_awarded     >= 0),
  gold_awarded    integer not null default 0 check (gold_awarded    >= 0),
  essence_awarded integer not null default 0 check (essence_awarded >= 0),
  energy_spent    smallint not null check (energy_spent >= 0),

  duration_ms integer not null check (duration_ms > 0),
  started_at  timestamptz not null,
  created_at  timestamptz not null default now(),

  -- No se puede matar al jefe sin haber limpiado los pisos.
  -- El 3 está hardcodeado porque un CHECK no puede leer dungeons.floors.
  -- Hoy todas las mazmorras tienen 3 pisos (PDF §6); si eso cambia, esta
  -- validación queda desalineada y hay que moverla a un trigger.
  constraint dungeon_runs_boss_needs_floors check (
    not boss_defeated or floors_cleared >= 3
  ),
  -- Un intento fallido no acredita nada.
  constraint dungeon_runs_failed_gives_nothing check (
    outcome = 'cleared' or (exp_awarded = 0 and gold_awarded = 0 and essence_awarded = 0)
  )
);

create index dungeon_runs_hunter_idx  on dungeon_runs (hunter_id, created_at desc);
create index dungeon_runs_dungeon_idx on dungeon_runs (dungeon_id, difficulty);

comment on table dungeon_runs is
  'Historial de intentos. Insertado solo por la Edge Function complete-dungeon-run.';

-- ─────────────────────────────────────────────────────────────
-- power_challenges
-- La evolución de poderes requiere "desafíos especiales" (PDF §6).
-- Acá se registra cuáles completó cada cazador.
-- ─────────────────────────────────────────────────────────────

create table power_challenges (
  hunter_id    uuid not null references hunters (id) on delete cascade,
  challenge_id text not null,
  completed_at timestamptz not null default now(),
  run_id       uuid references dungeon_runs (id) on delete set null,
  primary key (hunter_id, challenge_id)
);

-- ─────────────────────────────────────────────────────────────
-- RLS + grants
-- ─────────────────────────────────────────────────────────────

alter table dungeon_runs     enable row level security;
alter table power_challenges enable row level security;

create policy "dungeon_runs: read own" on dungeon_runs
  for select using (auth.uid() = hunter_id);

create policy "power_challenges: read own" on power_challenges
  for select using (auth.uid() = hunter_id);

revoke all on table dungeon_runs     from anon, authenticated;
revoke all on table power_challenges from anon, authenticated;

grant select on table dungeon_runs     to authenticated;
grant select on table power_challenges to authenticated;

-- ─────────────────────────────────────────────────────────────
-- dungeon_sessions
-- Intento en curso. Se crea al entrar (ahí se cobra la energía) y se
-- consume al terminar.
--
-- Por qué existe: si la energía se cobrara recién al finalizar, el jugador
-- podría jugar 60 s y recibir un rechazo por falta de energía. Y si no se
-- cobrara nada al entrar, un cliente modificado jugaría gratis.
-- ─────────────────────────────────────────────────────────────

create table dungeon_sessions (
  id            uuid primary key default gen_random_uuid(),
  hunter_id     uuid not null references hunters (id) on delete cascade,
  dungeon_id    text not null references dungeons (id),
  difficulty    dungeon_difficulty not null,
  rank_at_entry hunter_rank not null,
  energy_spent  smallint not null check (energy_spent >= 0),

  started_at    timestamptz not null default now(),
  expires_at    timestamptz not null,
  consumed_at   timestamptz,

  constraint dungeon_sessions_window check (expires_at > started_at)
);

-- Un cazador tiene como máximo una sesión viva. Evita abrir diez mazmorras
-- en paralelo y quedarse con la de mejor resultado.
create unique index dungeon_sessions_one_open_idx
  on dungeon_sessions (hunter_id)
  where consumed_at is null;

create index dungeon_sessions_expiry_idx on dungeon_sessions (expires_at)
  where consumed_at is null;

alter table dungeon_sessions enable row level security;

create policy "dungeon_sessions: read own" on dungeon_sessions
  for select using (auth.uid() = hunter_id);

revoke all on table dungeon_sessions from anon, authenticated;
grant select on table dungeon_sessions to authenticated;

-- Trazabilidad: qué sesión originó cada run.
alter table dungeon_runs
  add column session_id uuid unique references dungeon_sessions (id) on delete set null;
