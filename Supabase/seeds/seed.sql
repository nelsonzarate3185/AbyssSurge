-- seed.sql — datos de desarrollo local.
-- Se aplica con `make db-reset`, DESPUÉS de las migrations.
--
-- El catálogo del juego (clases, rangos, poderes, mazmorras, productos) NO
-- está acá: vive en 007_reference_data.sql porque también hace falta en
-- producción. Este archivo solo crea cazadores de prueba.
--
-- NO usar en producción: crea usuarios con contraseña conocida.

-- pgcrypto (crypt, gen_salt) vive en el schema `extensions` en Supabase.
set search_path = public, extensions;

-- ─────────────────────────────────────────────────────────────
-- Cazadores de prueba — uno por clase.
-- Contraseña de todos: devpassword
-- ─────────────────────────────────────────────────────────────

do $$
declare
  v_ids     uuid[] := array[
    '11111111-1111-1111-1111-111111111111'::uuid,
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid,
    '44444444-4444-4444-4444-444444444444'::uuid
  ];
  v_names   text[]         := array['Kael', 'Lyra', 'Vex', 'Vor'];
  v_classes hunter_class[] := array['dark_slayer', 'phantom_guard',
                                    'abyss_mage', 'beast_hunter']::hunter_class[];
  v_ranks   hunter_rank[]  := array['D', 'C', 'B', 'S']::hunter_rank[];
  v_exp     bigint[]       := array[1200, 4000, 12000, 60000];
  i int;
begin
  for i in 1..array_length(v_ids, 1) loop
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                            email_confirmed_at, created_at, updated_at)
    values (v_ids[i], '00000000-0000-0000-0000-000000000000',
            'authenticated', 'authenticated',
            lower(v_names[i]) || '@abysssurge.dev',
            crypt('devpassword', gen_salt('bf')),
            now(), now(), now())
    on conflict (id) do nothing;

    insert into hunters (id, display_name, class, rank, exp, gold, essence, gems, energy)
    values (v_ids[i], v_names[i], v_classes[i], v_ranks[i], v_exp[i],
            5000 * i, 800 * i, 250 * i, 50)
    on conflict (id) do nothing;

    -- Poder inicial de la clase, equipado en el slot 1.
    insert into hunter_powers (hunter_id, power_id, loadout_slot)
    select v_ids[i], p.id, 1
    from powers p
    where p.class = v_classes[i] and p.tier = 1 and p.kind = 'active'
    order by p.id
    limit 1
    on conflict do nothing;
  end loop;
end $$;

-- Kael tiene la cadena del Dark Slayer hasta tier 3, para probar evolve_power
-- con el tier 4 (que además exige rango S y un desafío).
insert into hunter_powers (hunter_id, power_id, loadout_slot) values
  ('11111111-1111-1111-1111-111111111111', 'ds_cortadura_abismo', 2),
  ('11111111-1111-1111-1111-111111111111', 'ds_tornada_oscura',   3)
on conflict do nothing;

insert into power_challenges (hunter_id, challenge_id) values
  ('11111111-1111-1111-1111-111111111111', 'challenge_abyss_cut'),
  ('11111111-1111-1111-1111-111111111111', 'challenge_dark_storm')
on conflict do nothing;

-- ─────────────────────────────────────────────────────────────
-- Un clan con miembros y roles, para probar RLS y set_clan_role.
-- member_count lo mantiene el trigger: se inserta en 0 a propósito.
-- ─────────────────────────────────────────────────────────────

insert into clans (id, name, tag, description, leader_id, citadel_level, defender_id, member_count)
values ('cccccccc-0000-0000-0000-000000000001',
        'Gildía Oscura', 'GILD', 'Buscamos esclavizar al Abismo.',
        '44444444-4444-4444-4444-444444444444', 3,
        '44444444-4444-4444-4444-444444444444', 0)
on conflict (id) do nothing;

insert into clan_members (hunter_id, clan_id, role) values
  ('44444444-4444-4444-4444-444444444444', 'cccccccc-0000-0000-0000-000000000001', 'leader'),
  ('33333333-3333-3333-3333-333333333333', 'cccccccc-0000-0000-0000-000000000001', 'captain'),
  ('22222222-2222-2222-2222-222222222222', 'cccccccc-0000-0000-0000-000000000001', 'member')
on conflict (hunter_id) do nothing;

-- Kael queda sin clan a propósito: sirve para probar join_clan y para
-- verificar que la RLS de clan_members no le muestre nada.

-- ─────────────────────────────────────────────────────────────
-- Historial: una mazmorra completada por Lyra.
-- Se arma sesión → run para respetar la FK y el flujo real.
-- ─────────────────────────────────────────────────────────────

insert into dungeon_sessions (id, hunter_id, dungeon_id, difficulty, rank_at_entry,
                              energy_spent, started_at, expires_at, consumed_at)
values ('55555555-0000-0000-0000-000000000001',
        '22222222-2222-2222-2222-222222222222',
        'grind_fisura_menor', 'normal', 'C', 10,
        now() - interval '2 hours',
        now() - interval '90 minutes',
        now() - interval '110 minutes')
on conflict (id) do nothing;

insert into dungeon_runs (hunter_id, dungeon_id, difficulty, rank_at_entry,
                          floors_cleared, boss_defeated, outcome,
                          exp_awarded, gold_awarded, essence_awarded, energy_spent,
                          duration_ms, started_at, session_id)
values ('22222222-2222-2222-2222-222222222222',
        'grind_fisura_menor', 'normal', 'C',
        3, true, 'cleared',
        150, 400, 25, 10,
        184000, now() - interval '2 hours',
        '55555555-0000-0000-0000-000000000001')
on conflict do nothing;

-- ─────────────────────────────────────────────────────────────
-- Comprobaciones rápidas
-- ─────────────────────────────────────────────────────────────

do $$
declare
  v_hunters int;
  v_powers  int;
  v_members int;
begin
  select count(*) into v_hunters from hunters;
  select count(*) into v_powers  from powers;
  select member_count into v_members from clans
   where id = 'cccccccc-0000-0000-0000-000000000001';

  raise notice 'seed: % cazadores, % poderes en catálogo, clan con % miembros',
    v_hunters, v_powers, v_members;

  if v_members <> 3 then
    raise warning 'member_count = %, se esperaban 3 — revisar el trigger sync_clan_member_count',
      v_members;
  end if;
end $$;
