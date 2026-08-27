# Supabase — Backend de AbyssSurge

Todo el estado autoritativo del juego vive acá: perfiles, economía,
runs validadas, naufragios y leaderboards.

## Principio de diseño

> **El cliente no decide recompensas.**

El cliente Unity puede leer lo suyo y llamar tres RPCs acotadas. Todo lo que
toca la economía pasa por una Edge Function con `service_role` que valida la
run antes de acreditar. Ver [GAME_MECHANICS.md §9](../GAME_MECHANICS.md).

## Setup

```bash
npm i -g supabase          # o: scoop install supabase
supabase login
supabase link --project-ref <tu-project-ref>

cd ..                      # los comandos corren desde la raíz del repo
make db-start              # levanta Postgres + Studio + Auth local
make db-reset              # migrations + seeds desde cero
```

Studio local: http://127.0.0.1:54323

> **Linux:** el CLI busca `supabase/config.toml` en minúscula. Creá un symlink
> una vez: `ln -s Supabase supabase`

## Estructura

```
Supabase/
├── config.toml            # configuración del stack local
├── migrations/            # schema versionado — se aplica en orden
│   ├── 001_initial_schema.sql
│   ├── 002_rls_policies.sql
│   ├── 003_rpc.sql
│   └── 004_credit_run.sql
├── functions/             # Edge Functions (Deno / TypeScript)
│   ├── _shared/           # helpers: auth, cors, seed determinista
│   ├── submit-run/        # valida y acredita una run
│   └── daily-seed/        # seed compartida del día
└── seeds/
    └── seed.sql           # datos de desarrollo
```

## Tablas

| Tabla | Quién escribe | Notas |
|---|---|---|
| `players` | RPC `bootstrap_player`, funciones server | El cliente solo puede renombrarse |
| `board_upgrades` | RPC `purchase_upgrade` | Costo `100 × nivel²` `[TUNE]` |
| `daily_seeds` | Edge Function `daily-seed` | Lectura pública autenticada |
| `runs` | Edge Function `submit-run` | El cliente **no** inserta |
| `wrecks` | `submit-run` / RPC `claim_wreck` | 60% al recuperador, 20% al dueño |
| `quotas` | `credit_run` | Presión narrativa como sistema |

Vista `leaderboard_daily`: top de las seeds de los últimos 7 días. No expone
`player_id`.

## RPCs disponibles para el cliente

| RPC | Qué hace |
|---|---|
| `bootstrap_player(display_name)` | Crea perfil + slots de tabla en el primer login |
| `purchase_upgrade(slot)` | Sube un slot un nivel cobrando Núcleos |
| `claim_wreck(wreck_id)` | Recupera el naufragio de otro jugador |

`credit_run(run_id)` existe pero está revocada para `authenticated` — solo
`service_role`.

## Edge Functions

```bash
make fn-serve                    # local, con hot reload, leyendo ../.env
make fn-deploy                   # todas
make fn-deploy NAME=submit-run   # una sola
```

Contrato completo de request/response: [../Docs/API/](../Docs/API/).

## Migrations

```bash
make db-diff NAME=add_contracts   # genera migration desde cambios locales
make db-push                      # aplica al proyecto remoto
```

Reglas:

- Una migration aplicada en remoto **no se edita**. Se agrega otra.
- Toda tabla nueva se crea con `enable row level security` en la **misma**
  migration. Sin excepciones.
- Nombres en `snake_case`, tablas en plural.

## Cosas a resolver

- [ ] Rate limiting en `submit-run` (hoy solo valida física y capacidad)
- [ ] Firma HMAC del payload de run además de la validación heurística
- [ ] Job semanal que cierre las cuotas (`quotas.settled`)
- [ ] Retención: purgar `runs` de más de 90 días que no sean récords
