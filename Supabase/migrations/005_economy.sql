-- 005_economy.sql
-- Gemas, compras y cosméticos.
--
-- Filosofía del PDF §8: SIN PAY2WIN. Las gemas compran conveniencia
-- (energía, revivir) y cosmética (skins, battle pass). Nunca poder.
-- El check `gem_sinks_no_power` de abajo hace cumplir eso a nivel schema.

create type purchase_status as enum ('pending', 'paid', 'failed', 'refunded', 'cancelled');
create type entitlement_kind as enum ('skin', 'battle_pass');

-- ─────────────────────────────────────────────────────────────
-- gem_products
-- Paquetes de gemas. Precios del PDF §8.
-- ─────────────────────────────────────────────────────────────

create table gem_products (
  sku        text primary key,
  gems       integer not null check (gems > 0),
  price_cents integer not null check (price_cents > 0),
  currency   char(3) not null default 'USD',
  bonus_pct  smallint not null default 0 check (bonus_pct >= 0),
  is_active  boolean not null default true,
  sort_order integer not null default 0
);

comment on column gem_products.price_cents is
  'Precio en la unidad mínima de la moneda. USD por ahora; MercadoPago '
  'Paraguay cobra en PYG (sin decimales) — ver Docs/API cuando se integre.';

-- ─────────────────────────────────────────────────────────────
-- gem_sinks
-- Catálogo de en qué se pueden gastar las gemas. Tabla, no enum: así
-- los precios se tunean sin migration.
-- ─────────────────────────────────────────────────────────────

create table gem_sinks (
  id          text primary key,
  label       text not null,
  gem_cost    integer not null check (gem_cost > 0),
  is_cosmetic boolean not null,
  is_active   boolean not null default true,

  -- El compromiso de "sin pay2win" en forma ejecutable: todo sink que no
  -- sea cosmético tiene que estar en esta lista blanca de conveniencia.
  constraint gem_sinks_no_power check (
    is_cosmetic or id in ('energy_refill', 'revive')
  )
);

-- ─────────────────────────────────────────────────────────────
-- purchases
-- Una fila por intento de compra. Agnóstica de proveedor: MercadoPago
-- Paraguay es el primero, pero también entran Google Play y App Store.
-- ─────────────────────────────────────────────────────────────

create table purchases (
  id          uuid primary key default gen_random_uuid(),
  hunter_id   uuid not null references hunters (id) on delete restrict,
  sku         text not null references gem_products (sku),

  -- Congelados al momento de la compra: si el precio cambia, el historial no.
  gems_granted integer not null check (gems_granted > 0),
  price_cents  integer not null check (price_cents > 0),
  currency     char(3) not null,

  provider      text not null default 'mercadopago',
  provider_ref  text,
  status        purchase_status not null default 'pending',
  raw_payload   jsonb,

  created_at timestamptz not null default now(),
  settled_at timestamptz,

  constraint purchases_settled_consistent check (
    (status in ('pending') and settled_at is null) or
    (status <> 'pending' and settled_at is not null)
  )
);

-- Idempotencia de webhooks: el mismo evento del proveedor no acredita dos veces.
create unique index purchases_provider_ref_idx
  on purchases (provider, provider_ref)
  where provider_ref is not null;

create index purchases_hunter_idx on purchases (hunter_id, created_at desc);

-- ─────────────────────────────────────────────────────────────
-- gem_ledger
-- Libro mayor append-only. Toda variación de gemas deja rastro.
-- Sin esto, un reclamo de "pagué y no me llegó" es imposible de auditar.
-- ─────────────────────────────────────────────────────────────

create table gem_ledger (
  id          bigint generated always as identity primary key,
  hunter_id   uuid not null references hunters (id) on delete cascade,
  delta       integer not null check (delta <> 0),
  balance_after bigint not null check (balance_after >= 0),

  reason      text not null,
  purchase_id uuid references purchases (id),
  sink_id     text references gem_sinks (id),

  created_at timestamptz not null default now(),

  -- Un movimiento es o una compra (entra) o un gasto (sale), nunca ambos.
  constraint gem_ledger_source check (
    (delta > 0 and purchase_id is not null and sink_id is null) or
    (delta < 0 and sink_id is not null and purchase_id is null) or
    (purchase_id is null and sink_id is null)   -- ajustes manuales de soporte
  )
);

create index gem_ledger_hunter_idx on gem_ledger (hunter_id, created_at desc);

-- ─────────────────────────────────────────────────────────────
-- entitlements
-- Lo que el jugador compró y posee: skins y battle pass.
-- ─────────────────────────────────────────────────────────────

create table entitlements (
  id         uuid primary key default gen_random_uuid(),
  hunter_id  uuid not null references hunters (id) on delete cascade,
  kind       entitlement_kind not null,
  sku        text not null,

  granted_at timestamptz not null default now(),
  expires_at timestamptz,   -- NULL = permanente. El battle pass es mensual.

  constraint entitlements_battle_pass_expires check (
    kind <> 'battle_pass' or expires_at is not null
  )
);

-- Una skin no se compra dos veces; un battle pass sí (uno por mes).
create unique index entitlements_unique_skin_idx
  on entitlements (hunter_id, sku)
  where kind = 'skin';

create index entitlements_active_idx on entitlements (hunter_id, kind)
  where expires_at is null or expires_at > now();

-- ─────────────────────────────────────────────────────────────
-- RLS + grants
-- ─────────────────────────────────────────────────────────────

alter table gem_products enable row level security;
alter table gem_sinks    enable row level security;
alter table purchases    enable row level security;
alter table gem_ledger   enable row level security;
alter table entitlements enable row level security;

create policy "gem_products: read active" on gem_products
  for select to authenticated using (is_active);

create policy "gem_sinks: read active" on gem_sinks
  for select to authenticated using (is_active);

create policy "purchases: read own" on purchases
  for select using (auth.uid() = hunter_id);

create policy "gem_ledger: read own" on gem_ledger
  for select using (auth.uid() = hunter_id);

create policy "entitlements: read own" on entitlements
  for select using (auth.uid() = hunter_id);

revoke all on table gem_products from anon, authenticated;
revoke all on table gem_sinks    from anon, authenticated;
revoke all on table purchases    from anon, authenticated;
revoke all on table gem_ledger   from anon, authenticated;
revoke all on table entitlements from anon, authenticated;

grant select on table gem_products to authenticated;
grant select on table gem_sinks    to authenticated;
grant select on table purchases    to authenticated;
grant select on table gem_ledger   to authenticated;
grant select on table entitlements to authenticated;

-- Nadie escribe acá desde el cliente. Crear una compra e iniciar el pago es
-- una Edge Function; acreditarla la hace el webhook del proveedor.
