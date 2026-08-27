-- 003_rpc.sql
-- RPCs que el cliente sí puede llamar. Todas SECURITY DEFINER con
-- search_path fijo y validación explícita del caller.

-- ─────────────────────────────────────────────────────────────
-- bootstrap_player: crea perfil + slots de tabla en el primer login.
-- ─────────────────────────────────────────────────────────────

create or replace function bootstrap_player(p_display_name text)
returns players
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_player players;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  insert into players (id, display_name)
  values (v_uid, p_display_name)
  on conflict (id) do update set display_name = excluded.display_name
  returning * into v_player;

  insert into board_upgrades (player_id, slot, level)
  select v_uid, s, 0 from unnest(enum_range(null::board_slot)) as s
  on conflict do nothing;

  return v_player;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- purchase_upgrade: sube un slot un nivel cobrando Núcleos.
-- Costo: 100 * (nivel_destino ^ 2)   [TUNE]
-- ─────────────────────────────────────────────────────────────

create or replace function purchase_upgrade(p_slot board_slot)
returns board_upgrades
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_level smallint;
  v_cost  bigint;
  v_row   board_upgrades;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select level into v_level
  from board_upgrades
  where player_id = v_uid and slot = p_slot
  for update;

  if not found then
    raise exception 'upgrade slot not initialised' using errcode = 'P0002';
  end if;

  if v_level >= 10 then
    raise exception 'slot already at max level' using errcode = 'P0001';
  end if;

  v_cost := 100 * power(v_level + 1, 2)::bigint;

  update players
     set cores = cores - v_cost
   where id = v_uid
     and cores >= v_cost;

  if not found then
    raise exception 'insufficient cores: need %', v_cost using errcode = 'P0001';
  end if;

  update board_upgrades
     set level = v_level + 1
   where player_id = v_uid and slot = p_slot
  returning * into v_row;

  return v_row;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- claim_wreck: recuperar el naufragio de otro jugador.
-- El recuperador se lleva el 60%; el dueño original recupera el 20%.
-- ─────────────────────────────────────────────────────────────

create or replace function claim_wreck(p_wreck_id uuid)
returns table (cores_awarded integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_wreck wrecks;
  v_share integer;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into v_wreck
  from wrecks
  where id = p_wreck_id and recovered_by is null
  for update;

  if not found then
    raise exception 'wreck not available' using errcode = 'P0002';
  end if;

  if v_wreck.player_id = v_uid then
    raise exception 'cannot recover own wreck' using errcode = 'P0001';
  end if;

  v_share := floor(v_wreck.cores_lost * 0.60)::integer;

  update wrecks
     set recovered_by = v_uid, recovered_at = now()
   where id = p_wreck_id;

  update players set cores = cores + v_share where id = v_uid;
  update players set cores = cores + floor(v_wreck.cores_lost * 0.20)::integer
   where id = v_wreck.player_id;

  cores_awarded := v_share;
  return next;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- Permisos: revocar el default y conceder explícitamente.
-- ─────────────────────────────────────────────────────────────

revoke all on function bootstrap_player(text)      from public;
revoke all on function purchase_upgrade(board_slot) from public;
revoke all on function claim_wreck(uuid)            from public;

grant execute on function bootstrap_player(text)      to authenticated;
grant execute on function purchase_upgrade(board_slot) to authenticated;
grant execute on function claim_wreck(uuid)            to authenticated;
