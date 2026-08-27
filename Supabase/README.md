# Supabase — Backend de Abyss Surge

Estado autoritativo del juego: cazadores, progresión, mazmorras, clanes y
economía de gemas.

| | |
|---|---|
| **Proyecto** | AbyssSurge |
| **Project ref** | `ocmroiupftpbsukuqvyu` |
| **URL** | `https://ocmroiupftpbsukuqvyu.supabase.co` |

## Principio de diseño

> **El cliente no acredita nada.**

El cliente Unity lee lo suyo, ejecuta nueve RPCs acotadas y llama tres Edge
Functions (la cuarta, `payment-webhook`, la llama MercadoPago). Todo lo que suma EXP, oro, esencia, gemas o rango pasa por
`service_role` después de validar.

Tres capas de defensa, en este orden:

1. **RLS** decide qué **filas** ve cada jugador
2. **Grants por columna** deciden qué **columnas** puede escribir
   — RLS no filtra columnas: sin el grant, la policy de `update` sobre
   `hunters` dejaría al jugador editarse el oro
3. **Edge Functions** validan la lógica de juego antes de acreditar

## Setup

```bash
npm i -g supabase          # o: scoop install supabase
supabase login
supabase link --project-ref ocmroiupftpbsukuqvyu

cd ..                      # los comandos corren desde la raíz del repo
cp .env.example .env       # completá anon key y service role key
make db-start              # Postgres + Studio + Auth local (necesita Docker)
make db-reset              # migrations + seeds desde cero
```

Studio local: http://127.0.0.1:54323

> **Linux:** el CLI busca `supabase/config.toml` en minúscula. Symlink una vez:
> `ln -s Supabase supabase`

## Estructura

```
Supabase/
├── config.toml
├── migrations/
│   ├── 001_enums_and_reference.sql   enums, catálogos vacíos, game_settings
│   ├── 002_hunters.sql               perfil, energía, loadout, grants por columna
│   ├── 003_dungeons.sql              sesiones e historial de mazmorras
│   ├── 004_clans.sql                 clanes, miembros, Clan Wars
│   ├── 005_economy.sql               gemas, compras, ledger, entitlements
│   ├── 006_rpc.sql                   lo que el cliente puede ejecutar
│   ├── 007_reference_data.sql        el catálogo del juego (también en prod)
│   ├── 008_award_run.sql             acreditación atómica, solo service_role
│   └── 009_mercadopago.sql           productos en PYG + acreditación de compras
├── functions/
│   ├── _shared/                      auth, cors, mercadopago
│   ├── enter-dungeon/                cobra energía, abre sesión
│   ├── complete-dungeon-run/         valida y acredita
│   ├── create-payment/               abre compra, devuelve link de checkout
│   └── payment-webhook/              recibe MercadoPago, acredita gemas
└── seeds/
    └── seed.sql                      cazadores de prueba (solo local)
```

**El catálogo va en migration, no en seeds.** Clases, rangos, poderes,
mazmorras y productos hacen falta en producción: sin ellos no se puede crear
un cazador. `seeds/` es solo para usuarios de prueba locales.

## Tablas

### Referencia (solo lectura para el cliente)

| Tabla | Qué define |
|---|---|
| `class_archetypes` | Las 4 clases y sus stats base — valores exactos del PDF §3 |
| `rank_tiers` | E→SSS: EXP requerida, multiplicador de stats, aura |
| `powers` | Catálogo. Los poderes evolucionan: cada tier es una fila que apunta a la anterior |
| `dungeons` | 3 pisos + 1 jefe, 10 de energía. Tipos: story, grind, awakening, clan |
| `difficulty_modifiers` | Normal / Hard / Imposible |
| `gem_products`, `gem_sinks` | Paquetes y usos de gemas |
| `game_settings` | Constantes tuneables sin migration |

### Estado del jugador

| Tabla | Quién escribe |
|---|---|
| `hunters` | RPCs y Edge Functions. El cliente solo puede tocar `display_name` |
| `hunter_powers` | `evolve_power()` desbloquea; el cliente solo mueve `loadout_slot` |
| `dungeon_sessions` | `enter-dungeon` |
| `dungeon_runs` | `award_dungeon_run()` — el cliente no tiene insert |
| `power_challenges` | Edge Functions |
| `story_progress` | `award_dungeon_run()` |
| `clans`, `clan_members` | RPCs de clan |
| `clan_wars`, `clan_war_battles` | *(pendiente: el scheduler de guerras)* |
| `purchases`, `gem_ledger`, `entitlements` | Webhook de pagos y `spend_gems()` |

Vista `hunter_stats`: stats efectivos = base de clase × multiplicador de rango.
Es `security_invoker = on`, así que hereda la RLS de `hunters`.

## Energía

No hay job de regeneración. `hunters.energy` guarda el último valor
materializado y `energy_updated_at` cuándo se materializó:

```
energía vigente = min(máximo, energy + minutos_transcurridos / 6)
```

`current_energy()` la lee, `spend_energy()` la materializa y descuenta.
Al gastar se preserva el avance parcial hacia el próximo punto — si no,
gastar reiniciaría el timer y el jugador perdería progreso.

Defaults: máximo 50, 1 punto cada 6 min (lleno en 5 h). Se tunean en
`game_settings` sin migration.

## Flujo de una mazmorra

```
enter-dungeon
  ├─ valida rango del cazador vs. mazmorra y dificultad
  ├─ si es mazmorra de clan, valida membresía
  ├─ cobra energía  (spend_energy)
  └─ abre dungeon_sessions  → sessionId, expira en 30 min

  ═══ combate offline, 30–60 s por encuentro ═══

complete-dungeon-run
  ├─ la sesión es del caller y sigue abierta
  ├─ coherencia: pisos ≤ los de la mazmorra, jefe requiere pisos completos
  ├─ tiempo: ni instantáneo ni fuera de la ventana de la sesión
  └─ award_dungeon_run()  ← una transacción
       consume sesión · registra run · suma EXP/oro/esencia
       promueve de rango · avanza el acto si era mazmorra de historia
```

La energía se cobra **al entrar**, no al salir. Si se cobrara al final, un
cliente modificado jugaría gratis; si no se cobrara nada al entrar, el jugador
podría gastar un minuto y comerse un rechazo por falta de energía.

## RPCs disponibles para el cliente

| RPC | Qué hace |
|---|---|
| `bootstrap_hunter(name, class)` | Crea el cazador y le da su poder tier 1 |
| `current_energy(hunter_id)` | Energía vigente |
| `evolve_power(power_id)` | Evoluciona un poder: prerequisito + desafío + esencia + oro |
| `spend_gems(sink_id)` | Recarga de energía, revivir, skin o battle pass |
| `create_clan(name, tag, desc)` | |
| `join_clan(clan_id)` | Valida cupo de 50, rango mínimo y que esté abierto |
| `leave_clan()` | El líder debe transferir antes de irse |
| `set_clan_role(hunter_id, role)` | Solo el líder |
| `set_clan_defender(hunter_id)` | Líder y capitanes |

Solo `service_role`: `spend_energy`, `refund_energy`, `award_dungeon_run`,
`expire_dungeon_sessions`, `credit_purchase`, `fail_purchase`.

## Pagos — MercadoPago Paraguay

```
create-payment                        MercadoPago
  ├─ lee el precio de gem_products      │
  │  (el cliente solo manda el SKU)     │
  ├─ crea purchases (pending)           │
  ├─ POST /checkout/preferences ────────▶
  │     external_reference = purchase.id
  └─ devuelve init_point ◀──────────────┘

  ═══ el jugador paga en el checkout ═══

payment-webhook  ◀──────────────────── notificación
  ├─ valida firma HMAC del x-signature
  ├─ GET /v1/payments/{id}  ← el estado real, no el body
  ├─ verifica que el monto y la moneda coincidan
  └─ credit_purchase()  → gemas + asiento en gem_ledger
```

Tres cosas que hacen que esto no se rompa:

- **`credit_purchase` es idempotente.** MercadoPago reintenta hasta recibir un
  2xx, así que la misma notificación llega varias veces. Una compra ya en
  `paid` devuelve la fila sin volver a sumar.
- **Casi todo responde 200.** Devolver 500 por una notificación que nunca
  vamos a poder procesar genera reintentos infinitos. Solo se devuelve error
  en fallos transitorios.
- **`payment-webhook` tiene `verify_jwt = false`** en `config.toml`.
  MercadoPago no manda JWT: autentica con la firma. Sin ese flag el webhook
  devuelve 401 y nada se acredita nunca.

**El guaraní no tiene subunidad.** `price_cents` guarda unidades mínimas y
`currency_exponent` dice cuántos decimales tiene la moneda: 2 para USD, 0 para
PYG. Sin eso el cliente muestra ₲7.000 como ₲70,00.

> ⚠️ **Los precios en PYG de `009_mercadopago.sql` son placeholder.** No salen
> de ninguna cotización real: están para que el flujo funcione end-to-end.
> Definilos antes de cobrarle a alguien.

## Sin pay2win, a nivel schema

El PDF §8 se compromete a que comprar no dé ventaja de poder. Eso está
codificado como constraint:

```sql
constraint gem_sinks_no_power check (
  is_cosmetic or id in ('energy_refill', 'revive')
)
```

Agregar un sink que dé stats o daño falla al insertarlo. No depende de que
alguien se acuerde de la regla.

## Estado real

**Nada de esto se ejecutó todavía.** No hay Docker ni Supabase CLI en la
máquina donde se escribió, así que el SQL no pasó por un parser y las Edge
Functions no pasaron por `deno check`. El primer `make db-reset` es la prueba.

## Pendientes

- [ ] Aplicar las migrations y arreglar lo que falle
- [ ] Scheduler de Clan Wars cada 3 días (pg_cron o Edge Function)
- [ ] `expire_dungeon_sessions()` programado
- [ ] Fijar los precios reales en PYG (hoy son placeholder)
- [ ] Job que cierre las compras `pending` viejas
- [ ] Probar el webhook con las credenciales de prueba de MercadoPago
- [ ] Cadenas de poderes de Phantom Guard, Abyss Mage y Beast Hunter
- [ ] Rate limiting en `enter-dungeon`
- [ ] Leaderboards (por rango, por clan)
- [ ] Retención de `dungeon_runs` viejas
