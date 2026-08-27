-- seed.sql — datos iniciales para desarrollo local.
-- Se aplica automáticamente con `make db-reset`.
-- NO usar en producción: crea usuarios de prueba con contraseñas conocidas.

-- pgcrypto (crypt, gen_salt) vive en el schema `extensions` en Supabase.
set search_path = public, extensions;

-- ─────────────────────────────────────────────────────────────
-- Seeds diarias de los últimos 7 días (para probar leaderboard).
-- ─────────────────────────────────────────────────────────────

insert into daily_seeds (seed_date, seed, modifiers)
select
  d::date,
  md5(d::text || ':dev-salt') || md5(d::text),
  case extract(dow from d)::int
    when 0 then '{"name":"still_water","oxygenMultiplier":1.15}'::jsonb
    when 1 then '{"name":"riptide","oxygenMultiplier":0.85,"lootMultiplier":1.4}'::jsonb
    when 2 then '{"name":"blackout","visibility":0.5,"lootMultiplier":1.6}'::jsonb
    when 3 then '{"name":"bloom","awakenedDensity":1.5}'::jsonb
    when 4 then '{"name":"cold_current","descentSpeed":1.25}'::jsonb
    when 5 then '{"name":"quota_day","lootMultiplier":2.0}'::jsonb
    else        '{"name":"clear"}'::jsonb
  end
from generate_series(
  (now() at time zone 'utc')::date - 6,
  (now() at time zone 'utc')::date,
  interval '1 day'
) as d
on conflict (seed_date) do nothing;

-- ─────────────────────────────────────────────────────────────
-- Jugadores de prueba.
-- Requiere que existan en auth.users; los creamos directamente
-- porque en local tenemos acceso al schema auth.
-- ─────────────────────────────────────────────────────────────

do $$
declare
  v_ids uuid[] := array[
    '11111111-1111-1111-1111-111111111111'::uuid,
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid
  ];
  v_names text[] := array['Vey', 'Ocho', 'Halla'];
  i int;
begin
  for i in 1..array_length(v_ids, 1) loop
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                            email_confirmed_at, created_at, updated_at)
    values (v_ids[i], '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            lower(v_names[i]) || '@abysssurge.dev', crypt('devpassword', gen_salt('bf')),
            now(), now(), now())
    on conflict (id) do nothing;

    insert into players (id, display_name, cores, scrap, corruption, deepest_meters)
    values (v_ids[i], v_names[i], 500 * i, 200 * i, 12 * i, 300 * i)
    on conflict (id) do nothing;

    insert into board_upgrades (player_id, slot, level)
    select v_ids[i], s, (i - 1)::smallint
    from unnest(enum_range(null::board_slot)) as s
    on conflict do nothing;
  end loop;
end $$;

-- ─────────────────────────────────────────────────────────────
-- Runs de ejemplo + un naufragio abierto para probar claim_wreck.
-- ─────────────────────────────────────────────────────────────

insert into runs (id, player_id, seed_date, seed, class, depth_meters,
                  cores_collected, scrap_collected, duration_ms, outcome,
                  credited, corruption_gain, started_at)
values
  ('aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111',
   (now() at time zone 'utc')::date,
   (select seed from daily_seeds where seed_date = (now() at time zone 'utc')::date),
   'diver', 840, 34, 12, 214000, 'ascended', true, 0, now() - interval '1 hour'),

  ('aaaaaaaa-0000-0000-0000-000000000002',
   '22222222-2222-2222-2222-222222222222',
   (now() at time zone 'utc')::date,
   (select seed from daily_seeds where seed_date = (now() at time zone 'utc')::date),
   'needle', 1260, 51, 8, 268000, 'crushed', false, 0, now() - interval '40 minutes')
on conflict (id) do nothing;

insert into wrecks (run_id, player_id, seed, depth_meters, cores_lost)
select r.id, r.player_id, r.seed, r.depth_meters, r.cores_collected
from runs r
where r.id = 'aaaaaaaa-0000-0000-0000-000000000002'
on conflict (run_id) do nothing;

-- ─────────────────────────────────────────────────────────────
-- Cuota de la semana en curso.
-- ─────────────────────────────────────────────────────────────

insert into quotas (player_id, week_start, cores_required, cores_delivered)
select id,
       date_trunc('week', now() at time zone 'utc')::date,
       250,
       0
from players
on conflict (player_id, week_start) do nothing;
