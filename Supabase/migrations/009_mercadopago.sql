-- 009_mercadopago.sql
-- Soporte para MercadoPago Paraguay: productos en PYG y acreditación
-- idempotente de compras.
--
-- El schema de 005_economy.sql ya era agnóstico de proveedor. Acá se agrega
-- lo específico de cobrar en guaraníes y el enganche con el webhook.

-- ─────────────────────────────────────────────────────────────
-- El guaraní no tiene subunidad
--
-- `gem_products.price_cents` guarda unidades mínimas de la moneda. Para USD
-- eso son centavos (exponente 2); para PYG son guaraníes enteros
-- (exponente 0). Sin este dato el cliente no sabe dónde poner la coma y
-- muestra ₲7.000 como ₲70,00.
-- ─────────────────────────────────────────────────────────────

alter table gem_products
  add column currency_exponent smallint not null default 2
    check (currency_exponent between 0 and 4);

comment on column gem_products.currency_exponent is
  'Decimales de la moneda: 2 para USD, 0 para PYG. price_cents está siempre '
  'en unidades mínimas; el cliente divide por 10^currency_exponent.';

-- La preferencia de Checkout Pro, para poder rastrear una compra que quedó
-- colgada sin haber recibido nunca el webhook.
alter table purchases
  add column preference_id text;

create index purchases_preference_idx on purchases (preference_id)
  where preference_id is not null;

-- Una compra pendiente vieja no sirve de nada y ensucia el historial.
create index purchases_pending_idx on purchases (created_at)
  where status = 'pending';

-- ─────────────────────────────────────────────────────────────
-- Productos en PYG
--
-- MercadoPago Paraguay cobra en guaraníes. Los precios en USD del PDF §8
-- no se pueden usar tal cual: hay que fijar precios locales.
--
-- ⚠️ ESTOS MONTOS SON PLACEHOLDER. [TUNE]
-- No salen de ninguna cotización real ni de una decisión comercial: están
-- puestos para que el flujo funcione end-to-end. Antes de cobrarle a alguien,
-- reemplazalos por los precios que definas vos.
-- ─────────────────────────────────────────────────────────────

insert into gem_products (sku, gems, price_cents, currency, currency_exponent, bonus_pct, sort_order) values
  ('gems_100_pyg',   100,  7000, 'PYG', 0,  0, 11),
  ('gems_500_pyg',   500, 35000, 'PYG', 0,  1, 21),
  ('gems_1200_pyg', 1200, 70000, 'PYG', 0, 20, 31)
on conflict (sku) do update set
  gems = excluded.gems, price_cents = excluded.price_cents,
  currency_exponent = excluded.currency_exponent, bonus_pct = excluded.bonus_pct;

-- Los productos en USD quedan activos para App Store / Google Play.
update gem_products set currency_exponent = 2 where currency = 'USD';

-- ─────────────────────────────────────────────────────────────
-- credit_purchase
--
-- Acredita una compra aprobada. Idempotente: el webhook de MercadoPago
-- reintenta hasta recibir un 2xx, así que esta función se va a llamar
-- varias veces con el mismo pago y solo la primera puede sumar gemas.
-- ─────────────────────────────────────────────────────────────

create or replace function credit_purchase(
  p_purchase_id uuid,
  p_provider_ref text,
  p_raw jsonb default null
)
returns purchases
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_purchase purchases;
  v_balance  bigint;
begin
  select * into v_purchase
  from purchases
  where id = p_purchase_id
  for update;

  if not found then
    raise exception 'purchase not found' using errcode = 'P0002';
  end if;

  -- Ya acreditada: devolver la fila sin tocar nada. NO es un error —
  -- si tirara excepción, el webhook respondería 500 y MercadoPago
  -- reintentaría para siempre.
  if v_purchase.status = 'paid' then
    return v_purchase;
  end if;

  if v_purchase.status <> 'pending' then
    raise exception 'purchase is % and cannot be credited', v_purchase.status
      using errcode = 'P0001';
  end if;

  update purchases
     set status = 'paid',
         provider_ref = coalesce(p_provider_ref, provider_ref),
         raw_payload = coalesce(p_raw, raw_payload),
         settled_at = now()
   where id = p_purchase_id
  returning * into v_purchase;

  update hunters
     set gems = gems + v_purchase.gems_granted
   where id = v_purchase.hunter_id
  returning gems into v_balance;

  insert into gem_ledger (hunter_id, delta, balance_after, reason, purchase_id)
  values (v_purchase.hunter_id, v_purchase.gems_granted, v_balance,
          'Compra ' || v_purchase.sku, v_purchase.id);

  return v_purchase;
end;
$fn$;

-- ─────────────────────────────────────────────────────────────
-- fail_purchase
-- Cierra una compra que el proveedor rechazó, canceló o devolvió.
-- ─────────────────────────────────────────────────────────────

create or replace function fail_purchase(
  p_purchase_id uuid,
  p_status purchase_status,
  p_provider_ref text default null,
  p_raw jsonb default null
)
returns purchases
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_purchase purchases;
  v_balance  bigint;
begin
  if p_status not in ('failed', 'cancelled', 'refunded') then
    raise exception 'invalid terminal status %', p_status using errcode = 'P0001';
  end if;

  select * into v_purchase from purchases where id = p_purchase_id for update;

  if not found then
    raise exception 'purchase not found' using errcode = 'P0002';
  end if;

  -- Devolución de una compra ya acreditada: hay que sacarle las gemas.
  -- Puede dejar el saldo en negativo si ya las gastó; el check de la columna
  -- lo impide, así que se descuenta hasta donde alcance y queda registrado.
  if v_purchase.status = 'paid' and p_status = 'refunded' then
    update hunters
       set gems = greatest(0, gems - v_purchase.gems_granted)
     where id = v_purchase.hunter_id
    returning gems into v_balance;

    insert into gem_ledger (hunter_id, delta, balance_after, reason, purchase_id)
    values (v_purchase.hunter_id, -v_purchase.gems_granted, v_balance,
            'Devolución ' || v_purchase.sku, v_purchase.id);

  elsif v_purchase.status <> 'pending' then
    -- Ya cerrada en un estado terminal: idempotente, no se toca.
    return v_purchase;
  end if;

  update purchases
     set status = p_status,
         provider_ref = coalesce(p_provider_ref, provider_ref),
         raw_payload = coalesce(p_raw, raw_payload),
         settled_at = now()
   where id = p_purchase_id
  returning * into v_purchase;

  return v_purchase;
end;
$fn$;

-- ─────────────────────────────────────────────────────────────
-- Permisos: solo el webhook, que corre con service_role.
-- ─────────────────────────────────────────────────────────────

revoke all on function credit_purchase(uuid, text, jsonb) from public;
revoke all on function credit_purchase(uuid, text, jsonb) from authenticated;
grant execute on function credit_purchase(uuid, text, jsonb) to service_role;

revoke all on function fail_purchase(uuid, purchase_status, text, jsonb) from public;
revoke all on function fail_purchase(uuid, purchase_status, text, jsonb) from authenticated;
grant execute on function fail_purchase(uuid, purchase_status, text, jsonb) to service_role;
