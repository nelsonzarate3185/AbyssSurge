-- 004_credit_run.sql
-- Acreditación atómica de una run. Solo la llama la Edge Function
-- `submit-run` con service_role — el cliente no tiene execute.

create or replace function credit_run(p_run_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_run runs;
begin
  select * into v_run from runs where id = p_run_id for update;

  if not found then
    raise exception 'run not found' using errcode = 'P0002';
  end if;

  if not v_run.credited then
    raise exception 'run is not creditable' using errcode = 'P0001';
  end if;

  update players
     set cores          = cores + v_run.cores_collected,
         scrap          = scrap + v_run.scrap_collected,
         corruption     = least(100, corruption + v_run.corruption_gain),
         deepest_meters = greatest(deepest_meters, v_run.depth_meters),
         runs_completed = runs_completed + 1
   where id = v_run.player_id;

  -- La cuota de la semana avanza con lo entregado (GAME_MECHANICS.md §7).
  update quotas
     set cores_delivered = cores_delivered + v_run.cores_collected
   where player_id = v_run.player_id
     and week_start = date_trunc('week', (v_run.started_at at time zone 'utc'))::date
     and not settled;
end;
$$;

revoke all on function credit_run(uuid) from public;
revoke all on function credit_run(uuid) from authenticated;
grant execute on function credit_run(uuid) to service_role;
