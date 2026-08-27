-- 006_rpc.sql
-- Lo único que el cliente puede ejecutar. Todas SECURITY DEFINER con
-- search_path fijo y validación explícita del caller.

-- ═════════════════════════════════════════════════════════════
-- ENERGÍA
-- ═════════════════════════════════════════════════════════════

/*
  Modelo: `hunters.energy` guarda el último valor materializado y
  `energy_updated_at` cuándo se materializó. La energía vigente le suma la
  regeneración transcurrida. No hay ningún job que la actualice: se calcula
  al leer y se materializa al gastar.
*/

create or replace function current_energy(p_hunter_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $fn$
  select least(
    setting_int('energy_max', 50),
    h.energy + floor(
      extract(epoch from (now() - h.energy_updated_at))
      / (setting_int('energy_regen_minutes', 6) * 60)
    )::integer
  )
  from hunters h
  where h.id = p_hunter_id;
$fn$;

comment on function current_energy(uuid) is
  'Energía vigente = materializada + regeneración acumulada, techada al máximo.';

/*
  Materializa la energía y descuenta `p_cost`. Devuelve la energía restante.
  Falla si no alcanza.

  El resto de la división se preserva en energy_updated_at: si faltaban 4 min
  para el próximo punto, siguen faltando 4 min después de gastar. Sin eso,
  gastar energía reiniciaría el timer y el jugador perdería progreso.
*/
create or replace function spend_energy(p_hunter_id uuid, p_cost integer)
returns integer
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_regen_seconds integer := setting_int('energy_regen_minutes', 6) * 60;
  v_max           integer := setting_int('energy_max', 50);
  v_available     integer;
  v_elapsed       integer;
  v_remainder     integer;
begin
  select least(v_max,
               h.energy + floor(extract(epoch from (now() - h.energy_updated_at))
                                / v_regen_seconds)::integer),
         extract(epoch from (now() - h.energy_updated_at))::integer
    into v_available, v_elapsed
  from hunters h
  where h.id = p_hunter_id
  for update;

  if not found then
    raise exception 'hunter not found' using errcode = 'P0002';
  end if;

  if v_available < p_cost then
    raise exception 'insufficient energy: have %, need %', v_available, p_cost
      using errcode = 'P0001';
  end if;

  -- Si ya estaba al máximo, el timer arranca de cero; si no, se conserva el
  -- avance parcial hacia el próximo punto.
  v_remainder := case when v_available >= v_max then 0
                      else v_elapsed % v_regen_seconds end;

  update hunters
     set energy = v_available - p_cost,
         energy_updated_at = now() - make_interval(secs => v_remainder)
   where id = p_hunter_id;

  return v_available - p_cost;
end;
$fn$;

-- ═════════════════════════════════════════════════════════════
-- ONBOARDING
-- ═════════════════════════════════════════════════════════════

/*
  Crea el cazador y le da el poder tier 1 de su clase, equipado en el slot 1.
  Idempotente en el nombre; la clase NO se puede cambiar después.
*/
create or replace function bootstrap_hunter(p_display_name text, p_class hunter_class)
returns hunters
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_uid     uuid := auth.uid();
  v_hunter  hunters;
  v_starter text;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  insert into hunters (id, display_name, class, energy)
  values (v_uid, p_display_name, p_class, setting_int('energy_max', 50))
  on conflict (id) do update set display_name = excluded.display_name
  returning * into v_hunter;

  select id into v_starter
  from powers
  where class = v_hunter.class and tier = 1 and kind = 'active'
  order by id
  limit 1;

  if v_starter is not null then
    insert into hunter_powers (hunter_id, power_id, loadout_slot)
    values (v_uid, v_starter, 1)
    on conflict do nothing;
  end if;

  return v_hunter;
end;
$fn$;

-- ═════════════════════════════════════════════════════════════
-- PODERES
-- ═════════════════════════════════════════════════════════════

/*
  Evoluciona un poder. Requiere (PDF §6):
    - poseer el poder anterior de la cadena
    - haber completado el desafío especial, si el poder lo pide
    - esencia + oro suficientes
    - el rango mínimo del poder

  El poder anterior NO se pierde: queda desbloqueado y se puede seguir
  equipando. Evolucionar amplía el loadout disponible, no lo reemplaza.
*/
create or replace function evolve_power(p_power_id text)
returns hunter_powers
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_uid    uuid := auth.uid();
  v_power  powers;
  v_hunter hunters;
  v_row    hunter_powers;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into v_power from powers where id = p_power_id;
  if not found then
    raise exception 'unknown power %', p_power_id using errcode = 'P0002';
  end if;

  select * into v_hunter from hunters where id = v_uid for update;

  if v_hunter.class <> v_power.class then
    raise exception 'power belongs to another class' using errcode = 'P0001';
  end if;

  if v_hunter.rank < v_power.min_rank then
    raise exception 'rank % required', v_power.min_rank using errcode = 'P0001';
  end if;

  if exists (select 1 from hunter_powers
             where hunter_id = v_uid and power_id = p_power_id) then
    raise exception 'power already unlocked' using errcode = 'P0001';
  end if;

  if v_power.evolves_from is not null
     and not exists (select 1 from hunter_powers
                     where hunter_id = v_uid and power_id = v_power.evolves_from) then
    raise exception 'missing prerequisite power %', v_power.evolves_from
      using errcode = 'P0001';
  end if;

  if v_power.challenge_id is not null
     and not exists (select 1 from power_challenges
                     where hunter_id = v_uid and challenge_id = v_power.challenge_id) then
    raise exception 'challenge % not completed', v_power.challenge_id
      using errcode = 'P0001';
  end if;

  update hunters
     set essence = essence - v_power.essence_cost,
         gold    = gold    - v_power.gold_cost
   where id = v_uid
     and essence >= v_power.essence_cost
     and gold    >= v_power.gold_cost;

  if not found then
    raise exception 'insufficient resources: need % essence, % gold',
      v_power.essence_cost, v_power.gold_cost using errcode = 'P0001';
  end if;

  insert into hunter_powers (hunter_id, power_id)
  values (v_uid, p_power_id)
  returning * into v_row;

  return v_row;
end;
$fn$;

-- ═════════════════════════════════════════════════════════════
-- GEMAS
-- ═════════════════════════════════════════════════════════════

/*
  Gasta gemas en un sink del catálogo. `energy_refill` tiene efecto directo;
  los cosméticos otorgan un entitlement.

  El check `gem_sinks_no_power` de 005_economy.sql garantiza que no pueda
  existir un sink que dé ventaja de poder. Acá no hace falta revalidarlo.
*/
create or replace function spend_gems(p_sink_id text)
returns bigint
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_uid     uuid := auth.uid();
  v_sink    gem_sinks;
  v_balance bigint;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into v_sink from gem_sinks where id = p_sink_id and is_active;
  if not found then
    raise exception 'unknown or inactive sink %', p_sink_id using errcode = 'P0002';
  end if;

  update hunters
     set gems = gems - v_sink.gem_cost
   where id = v_uid and gems >= v_sink.gem_cost
  returning gems into v_balance;

  if not found then
    raise exception 'insufficient gems: need %', v_sink.gem_cost using errcode = 'P0001';
  end if;

  insert into gem_ledger (hunter_id, delta, balance_after, reason, sink_id)
  values (v_uid, -v_sink.gem_cost, v_balance, v_sink.label, v_sink.id);

  if p_sink_id = 'energy_refill' then
    update hunters
       set energy = setting_int('energy_max', 50),
           energy_updated_at = now()
     where id = v_uid;

  elsif v_sink.is_cosmetic then
    insert into entitlements (hunter_id, kind, sku, expires_at)
    values (
      v_uid,
      case when p_sink_id = 'battle_pass' then 'battle_pass' else 'skin' end::entitlement_kind,
      p_sink_id,
      case when p_sink_id = 'battle_pass' then now() + interval '30 days' else null end
    )
    on conflict do nothing;
  end if;

  -- 'revive' no deja efecto persistente: lo consume la run en curso.
  return v_balance;
end;
$fn$;

-- ═════════════════════════════════════════════════════════════
-- CLANES
-- ═════════════════════════════════════════════════════════════

create or replace function create_clan(p_name text, p_tag text, p_description text default null)
returns clans
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_uid  uuid := auth.uid();
  v_clan clans;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if exists (select 1 from clan_members where hunter_id = v_uid) then
    raise exception 'already in a clan' using errcode = 'P0001';
  end if;

  insert into clans (name, tag, description, leader_id, member_count)
  values (p_name, upper(p_tag), p_description, v_uid, 0)
  returning * into v_clan;

  -- El trigger de clan_members lleva member_count a 1.
  insert into clan_members (hunter_id, clan_id, role)
  values (v_uid, v_clan.id, 'leader');

  select * into v_clan from clans where id = v_clan.id;
  return v_clan;
end;
$fn$;

create or replace function join_clan(p_clan_id uuid)
returns clan_members
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_uid    uuid := auth.uid();
  v_clan   clans;
  v_hunter hunters;
  v_row    clan_members;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if exists (select 1 from clan_members where hunter_id = v_uid) then
    raise exception 'already in a clan' using errcode = 'P0001';
  end if;

  select * into v_clan from clans where id = p_clan_id for update;
  if not found then
    raise exception 'clan not found' using errcode = 'P0002';
  end if;

  if not v_clan.is_open then
    raise exception 'clan is closed' using errcode = 'P0001';
  end if;

  if v_clan.member_count >= 50 then
    raise exception 'clan is full' using errcode = 'P0001';
  end if;

  select * into v_hunter from hunters where id = v_uid;
  if v_hunter.rank < v_clan.min_rank then
    raise exception 'rank % required', v_clan.min_rank using errcode = 'P0001';
  end if;

  insert into clan_members (hunter_id, clan_id, role)
  values (v_uid, p_clan_id, 'member')
  returning * into v_row;

  return v_row;
end;
$fn$;

/*
  Salir del clan. El líder no puede irse sin transferir el liderazgo:
  un clan sin líder no tiene quién lo administre.
*/
create or replace function leave_clan()
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_row clan_members;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into v_row from clan_members where hunter_id = v_uid;
  if not found then
    raise exception 'not in a clan' using errcode = 'P0002';
  end if;

  if v_row.role = 'leader' then
    raise exception 'transfer leadership before leaving' using errcode = 'P0001';
  end if;

  -- Si era el defensor de la ciudadela, el puesto queda vacante.
  update clans set defender_id = null
   where id = v_row.clan_id and defender_id = v_uid;

  delete from clan_members where hunter_id = v_uid;
end;
$fn$;

/*
  Cambiar el rol de un miembro. Solo el líder. Asignar 'leader' transfiere
  el clan y degrada al líder saliente a capitán.
*/
create or replace function set_clan_role(p_hunter_id uuid, p_role clan_role)
returns clan_members
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_uid    uuid := auth.uid();
  v_caller clan_members;
  v_target clan_members;
  v_row    clan_members;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into v_caller from clan_members where hunter_id = v_uid;
  if not found or v_caller.role <> 'leader' then
    raise exception 'only the leader can assign roles' using errcode = '42501';
  end if;

  select * into v_target from clan_members where hunter_id = p_hunter_id;
  if not found or v_target.clan_id <> v_caller.clan_id then
    raise exception 'target is not in your clan' using errcode = 'P0002';
  end if;

  if p_role = 'leader' then
    update clans set leader_id = p_hunter_id where id = v_caller.clan_id;
    update clan_members set role = 'captain' where hunter_id = v_uid;
  end if;

  update clan_members set role = p_role
   where hunter_id = p_hunter_id
  returning * into v_row;

  return v_row;
end;
$fn$;

/*
  Designar al defensor de la ciudadela. Líder y capitanes.
*/
create or replace function set_clan_defender(p_hunter_id uuid)
returns clans
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_uid    uuid := auth.uid();
  v_caller clan_members;
  v_clan   clans;
begin
  select * into v_caller from clan_members where hunter_id = v_uid;
  if not found or v_caller.role not in ('leader', 'captain') then
    raise exception 'only leader or captains can set the defender' using errcode = '42501';
  end if;

  if not exists (select 1 from clan_members
                 where hunter_id = p_hunter_id and clan_id = v_caller.clan_id) then
    raise exception 'defender must be a clan member' using errcode = 'P0002';
  end if;

  update clans set defender_id = p_hunter_id
   where id = v_caller.clan_id
  returning * into v_clan;

  return v_clan;
end;
$fn$;

-- ═════════════════════════════════════════════════════════════
-- PERMISOS
-- Revocar el default de PUBLIC y conceder una por una.
-- ═════════════════════════════════════════════════════════════

revoke all on function current_energy(uuid)                 from public;
revoke all on function spend_energy(uuid, integer)          from public;
revoke all on function bootstrap_hunter(text, hunter_class) from public;
revoke all on function evolve_power(text)                   from public;
revoke all on function spend_gems(text)                     from public;
revoke all on function create_clan(text, text, text)        from public;
revoke all on function join_clan(uuid)                      from public;
revoke all on function leave_clan()                         from public;
revoke all on function set_clan_role(uuid, clan_role)       from public;
revoke all on function set_clan_defender(uuid)              from public;

grant execute on function current_energy(uuid)                 to authenticated;
grant execute on function bootstrap_hunter(text, hunter_class) to authenticated;
grant execute on function evolve_power(text)                   to authenticated;
grant execute on function spend_gems(text)                     to authenticated;
grant execute on function create_clan(text, text, text)        to authenticated;
grant execute on function join_clan(uuid)                      to authenticated;
grant execute on function leave_clan()                         to authenticated;
grant execute on function set_clan_role(uuid, clan_role)       to authenticated;
grant execute on function set_clan_defender(uuid)              to authenticated;

-- spend_energy NO se expone al cliente: entrar a una mazmorra pasa por la
-- Edge Function, que además valida rango y dificultad.
grant execute on function spend_energy(uuid, integer) to service_role;

/*
  Devuelve energía sin pasarse del máximo. La usa `enter-dungeon` cuando
  cobró la energía pero después no pudo abrir la sesión.

  No es spend_energy con signo negativo: eso saltearía el techo y regalaría
  energía por encima del máximo.
*/
create or replace function refund_energy(p_hunter_id uuid, p_amount integer)
returns integer
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_max       integer := setting_int('energy_max', 50);
  v_available integer;
begin
  if p_amount <= 0 then
    raise exception 'refund amount must be positive' using errcode = 'P0001';
  end if;

  v_available := current_energy(p_hunter_id);

  update hunters
     set energy = least(v_max, v_available + p_amount),
         energy_updated_at = now()
   where id = p_hunter_id;

  return least(v_max, v_available + p_amount);
end;
$fn$;

revoke all on function refund_energy(uuid, integer) from public;
grant execute on function refund_energy(uuid, integer) to service_role;
