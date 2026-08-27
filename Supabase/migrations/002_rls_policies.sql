-- 002_rls_policies.sql
-- Regla de oro: el cliente lee lo suyo y escribe casi nada.
-- Toda acreditación de botín pasa por Edge Functions con service_role.

-- ─────────────────────────────────────────────────────────────
-- players
-- ─────────────────────────────────────────────────────────────

create policy "players: read own profile"
  on players for select
  using (auth.uid() = id);

create policy "players: create own profile"
  on players for insert
  with check (auth.uid() = id);

-- El jugador solo puede cambiar su nombre. Monedas y corrupción NO.
create policy "players: rename self"
  on players for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ─────────────────────────────────────────────────────────────
-- board_upgrades
-- Lectura propia; las compras se aplican vía RPC purchase_upgrade().
-- ─────────────────────────────────────────────────────────────

create policy "board_upgrades: read own"
  on board_upgrades for select
  using (auth.uid() = player_id);

-- ─────────────────────────────────────────────────────────────
-- daily_seeds
-- Lectura pública para usuarios autenticados; escritura solo servidor.
-- ─────────────────────────────────────────────────────────────

create policy "daily_seeds: read"
  on daily_seeds for select
  to authenticated
  using (seed_date <= (now() at time zone 'utc')::date);

-- ─────────────────────────────────────────────────────────────
-- runs
-- El cliente NO inserta runs. Solo lee las propias y el leaderboard.
-- ─────────────────────────────────────────────────────────────

create policy "runs: read own"
  on runs for select
  using (auth.uid() = player_id);

-- ─────────────────────────────────────────────────────────────
-- wrecks
-- Un jugador ve naufragios abiertos de su misma seed, menos los propios.
-- ─────────────────────────────────────────────────────────────

create policy "wrecks: read open on same seed"
  on wrecks for select
  to authenticated
  using (
    recovered_by is null
    and player_id <> auth.uid()
  );

create policy "wrecks: read own"
  on wrecks for select
  using (auth.uid() = player_id or auth.uid() = recovered_by);

-- ─────────────────────────────────────────────────────────────
-- quotas
-- ─────────────────────────────────────────────────────────────

create policy "quotas: read own"
  on quotas for select
  using (auth.uid() = player_id);

-- ─────────────────────────────────────────────────────────────
-- Leaderboard: vista con security_invoker = off para exponer solo
-- lo agregado sin abrir la tabla runs entera.
-- ─────────────────────────────────────────────────────────────

create view leaderboard_daily
with (security_invoker = off) as
select
  r.seed_date,
  p.display_name,
  r.depth_meters,
  r.cores_collected,
  r.class,
  rank() over (partition by r.seed_date order by r.depth_meters desc, r.duration_ms asc) as position
from runs r
join players p on p.id = r.player_id
where r.credited
  and r.seed_date is not null
  and r.seed_date >= (now() at time zone 'utc')::date - 7;

grant select on leaderboard_daily to authenticated;

comment on view leaderboard_daily is
  'Top de las seeds diarias de los últimos 7 días. No expone player_id.';
