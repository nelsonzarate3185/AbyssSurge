-- 004_clans.sql
-- Capa estratégica: clanes de hasta 50, ciudadela con defensor,
-- Clan Wars cada 3 días (PDF §6).

create table clans (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique check (char_length(name) between 3 and 24),
  tag         text not null unique check (tag ~ '^[A-Z0-9]{2,5}$'),
  description text check (char_length(description) <= 200),

  leader_id   uuid not null references hunters (id) on delete restrict,

  -- Ciudadela: el defensor es un miembro que representa al clan en la defensa.
  citadel_level smallint not null default 1 check (citadel_level between 1 and 10),
  defender_id   uuid references hunters (id) on delete set null,

  member_count smallint not null default 1 check (member_count between 0 and 50),
  min_rank     hunter_rank not null default 'E',
  is_open      boolean not null default true,

  war_wins   integer not null default 0 check (war_wins   >= 0),
  war_losses integer not null default 0 check (war_losses >= 0),

  created_at timestamptz not null default now()
);

comment on column clans.member_count is
  'Desnormalizado y mantenido por trigger. El límite de 50 del PDF se hace '
  'cumplir acá, no en el cliente.';

create table clan_members (
  hunter_id uuid primary key references hunters (id) on delete cascade,
  clan_id   uuid not null references clans (id) on delete cascade,
  role      clan_role not null default 'member',
  joined_at timestamptz not null default now(),

  -- Contribución a la guerra en curso
  war_score integer not null default 0 check (war_score >= 0)
);

create index clan_members_clan_idx on clan_members (clan_id, role);

comment on table clan_members is
  'hunter_id es PK: un cazador pertenece como máximo a un clan.';

-- ─────────────────────────────────────────────────────────────
-- clan_wars
-- ─────────────────────────────────────────────────────────────

create table clan_wars (
  id           uuid primary key default gen_random_uuid(),
  clan_a       uuid not null references clans (id) on delete cascade,
  clan_b       uuid not null references clans (id) on delete cascade,

  status       war_status not null default 'scheduled',
  starts_at    timestamptz not null,
  ends_at      timestamptz not null,

  score_a      integer not null default 0 check (score_a >= 0),
  score_b      integer not null default 0 check (score_b >= 0),
  winner_id    uuid references clans (id),

  created_at   timestamptz not null default now(),

  constraint clan_wars_distinct_clans check (clan_a <> clan_b),
  constraint clan_wars_window check (ends_at > starts_at),
  constraint clan_wars_winner_is_participant check (
    winner_id is null or winner_id in (clan_a, clan_b)
  ),
  constraint clan_wars_winner_only_when_ended check (
    winner_id is null or status = 'ended'
  )
);

create index clan_wars_active_idx on clan_wars (status, ends_at)
  where status <> 'ended';

-- Un clan no puede estar en dos guerras activas a la vez.
create unique index clan_wars_one_active_a on clan_wars (clan_a) where status <> 'ended';
create unique index clan_wars_one_active_b on clan_wars (clan_b) where status <> 'ended';

create table clan_war_battles (
  id        uuid primary key default gen_random_uuid(),
  war_id    uuid not null references clan_wars (id) on delete cascade,
  attacker_id uuid not null references hunters (id) on delete cascade,
  defender_id uuid not null references hunters (id) on delete cascade,
  run_id    uuid references dungeon_runs (id) on delete set null,

  points    integer not null default 0 check (points >= 0),
  won       boolean not null,
  created_at timestamptz not null default now(),

  constraint clan_war_battles_no_self check (attacker_id <> defender_id)
);

create index clan_war_battles_war_idx on clan_war_battles (war_id, created_at desc);

-- ─────────────────────────────────────────────────────────────
-- member_count por trigger
-- ─────────────────────────────────────────────────────────────

create or replace function sync_clan_member_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update clans set member_count = member_count + 1 where id = new.clan_id;
  elsif tg_op = 'DELETE' then
    update clans set member_count = greatest(0, member_count - 1) where id = old.clan_id;
  elsif tg_op = 'UPDATE' and new.clan_id <> old.clan_id then
    update clans set member_count = greatest(0, member_count - 1) where id = old.clan_id;
    update clans set member_count = member_count + 1 where id = new.clan_id;
  end if;
  return null;
end;
$$;

create trigger clan_members_sync_count
  after insert or update or delete on clan_members
  for each row execute function sync_clan_member_count();

-- ─────────────────────────────────────────────────────────────
-- RLS + grants
--
-- Los clanes son semi-públicos: hay que poder buscarlos para unirse.
-- La membresía y las guerras, en cambio, solo las ve el propio clan.
-- ─────────────────────────────────────────────────────────────

alter table clans            enable row level security;
alter table clan_members     enable row level security;
alter table clan_wars        enable row level security;
alter table clan_war_battles enable row level security;

-- Helper: clan del usuario actual. STABLE para que el planner lo cachee.
create or replace function current_clan_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select clan_id from clan_members where hunter_id = auth.uid();
$$;

create policy "clans: browse" on clans
  for select to authenticated using (true);

create policy "clan_members: read own clan" on clan_members
  for select to authenticated using (clan_id = current_clan_id());

create policy "clan_wars: read own clan wars" on clan_wars
  for select to authenticated
  using (clan_a = current_clan_id() or clan_b = current_clan_id());

create policy "clan_war_battles: read own clan wars" on clan_war_battles
  for select to authenticated
  using (exists (
    select 1 from clan_wars w
    where w.id = war_id
      and (w.clan_a = current_clan_id() or w.clan_b = current_clan_id())
  ));

revoke all on table clans            from anon, authenticated;
revoke all on table clan_members     from anon, authenticated;
revoke all on table clan_wars        from anon, authenticated;
revoke all on table clan_war_battles from anon, authenticated;

grant select on table clans            to authenticated;
grant select on table clan_members     to authenticated;
grant select on table clan_wars        to authenticated;
grant select on table clan_war_battles to authenticated;

-- Crear clan, unirse, salir y promover son RPCs — ver 006_rpc.sql.

revoke all on function current_clan_id() from public;
grant execute on function current_clan_id() to authenticated;
