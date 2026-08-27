-- 008_award_run.sql
-- Acreditación de una mazmorra completada. Solo service_role: la llama la
-- Edge Function `complete-dungeon-run` después de validar.
--
-- Hace en una sola transacción: consumir la sesión, registrar la run,
-- sumar recompensas y promover de rango si corresponde.

create or replace function award_dungeon_run(
  p_session_id     uuid,
  p_floors_cleared smallint,
  p_boss_defeated  boolean,
  p_outcome        run_outcome,
  p_duration_ms    integer
)
returns dungeon_runs
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_session    dungeon_sessions;
  v_dungeon    dungeons;
  v_difficulty difficulty_modifiers;
  v_run        dungeon_runs;
  v_exp        integer := 0;
  v_gold       integer := 0;
  v_essence    integer := 0;
  v_new_exp    bigint;
  v_new_rank   hunter_rank;
begin
  select * into v_session
  from dungeon_sessions
  where id = p_session_id and consumed_at is null
  for update;

  if not found then
    raise exception 'session not found or already consumed' using errcode = 'P0002';
  end if;

  if now() > v_session.expires_at then
    -- Se consume igual: la energía ya se cobró y la sesión no puede reciclarse.
    update dungeon_sessions set consumed_at = now() where id = p_session_id;
    raise exception 'session expired' using errcode = 'P0001';
  end if;

  select * into v_dungeon    from dungeons             where id = v_session.dungeon_id;
  select * into v_difficulty from difficulty_modifiers where difficulty = v_session.difficulty;

  -- Solo un intento limpio acredita. El check de dungeon_runs lo reafirma.
  if p_outcome = 'cleared' then
    v_exp     := floor(v_dungeon.base_exp     * v_difficulty.reward_multiplier)::integer;
    v_gold    := floor(v_dungeon.base_gold    * v_difficulty.reward_multiplier)::integer;
    v_essence := floor(v_dungeon.base_essence * v_difficulty.reward_multiplier)::integer;
  end if;

  update dungeon_sessions set consumed_at = now() where id = p_session_id;

  insert into dungeon_runs (
    hunter_id, dungeon_id, difficulty, rank_at_entry,
    floors_cleared, boss_defeated, outcome,
    exp_awarded, gold_awarded, essence_awarded, energy_spent,
    duration_ms, started_at, session_id
  ) values (
    v_session.hunter_id, v_session.dungeon_id, v_session.difficulty, v_session.rank_at_entry,
    p_floors_cleared, p_boss_defeated, p_outcome,
    v_exp, v_gold, v_essence, v_session.energy_spent,
    p_duration_ms, v_session.started_at, p_session_id
  )
  returning * into v_run;

  if p_outcome <> 'cleared' then
    return v_run;
  end if;

  update hunters
     set exp     = exp     + v_exp,
         gold    = gold    + v_gold,
         essence = essence + v_essence
   where id = v_session.hunter_id
  returning exp into v_new_exp;

  -- Promoción: el rango más alto cuya EXP requerida ya se alcanzó.
  select rank into v_new_rank
  from rank_tiers
  where exp_required <= v_new_exp
  order by tier desc
  limit 1;

  update hunters set rank = v_new_rank
   where id = v_session.hunter_id and rank < v_new_rank;

  -- Avance de historia: completar la mazmorra del acto lo cierra.
  if v_dungeon.type = 'story' then
    insert into story_progress (hunter_id, act)
    values (v_session.hunter_id, v_dungeon.story_act)
    on conflict do nothing;

    update hunters
       set story_act = least(6, greatest(story_act, v_dungeon.story_act + 1))
     where id = v_session.hunter_id;
  end if;

  return v_run;
end;
$fn$;

revoke all on function award_dungeon_run(uuid, smallint, boolean, run_outcome, integer) from public;
revoke all on function award_dungeon_run(uuid, smallint, boolean, run_outcome, integer) from authenticated;
grant execute on function award_dungeon_run(uuid, smallint, boolean, run_outcome, integer) to service_role;

-- ─────────────────────────────────────────────────────────────
-- Limpieza de sesiones vencidas. Programar con pg_cron o Edge Function.
-- ─────────────────────────────────────────────────────────────

create or replace function expire_dungeon_sessions()
returns integer
language sql
security definer
set search_path = public
as $fn$
  with expired as (
    update dungeon_sessions
       set consumed_at = now()
     where consumed_at is null and expires_at < now()
    returning 1
  )
  select count(*)::integer from expired;
$fn$;

revoke all on function expire_dungeon_sessions() from public;
grant execute on function expire_dungeon_sessions() to service_role;
