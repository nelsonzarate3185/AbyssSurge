# Contrato de API

Base URL: `$SUPABASE_URL`

Todas las llamadas requieren:

```http
apikey: <SUPABASE_ANON_KEY>
Authorization: Bearer <access_token>
Content-Type: application/json
```

La `anon key` es pública por diseño — lo que protege es RLS. La
`service_role` key **nunca** sale del servidor.

---

## Edge Functions

### `POST /functions/v1/daily-seed`

Devuelve la seed compartida del día. La materializa si no existía.

**Request:** `{}`

**Response `200`:**
```json
{
  "date": "2026-08-27",
  "seed": "9f2c4ab1d7e05836",
  "modifiers": { "name": "riptide", "oxygenMultiplier": 0.85, "lootMultiplier": 1.4 }
}
```

El cliente reproduce el nivel localmente con `DeterministicRandom(seed)`.
La seed **nunca** se genera en el cliente.

---

### `POST /functions/v1/submit-run`

Única vía para acreditar una run. Valida antes de tocar la economía.

**Request:**
```json
{
  "seed": "9f2c4ab1d7e05836",
  "seedDate": "2026-08-27",
  "class": "diver",
  "depthMeters": 840,
  "coresCollected": 34,
  "scrapCollected": 12,
  "durationMs": 214000,
  "outcome": "ascended",
  "startedAt": "2026-08-27T14:02:11.000Z"
}
```

| Campo | Tipo | Notas |
|---|---|---|
| `seed` | string | ≥ 8 chars |
| `seedDate` | string \| omitido | Presente solo en la run diaria |
| `class` | enum | `diver` \| `ballast` \| `needle` \| `scavenger` |
| `depthMeters` | int ≥ 0 | Profundidad **máxima** alcanzada, no la final |
| `outcome` | enum | `ascended` \| `drowned` \| `crushed` \| `abandoned` |
| `startedAt` | ISO-8601 UTC | Se valida contra el reloj del servidor |

**Response `200`:**
```json
{
  "runId": "0f8b…",
  "credited": true,
  "coresAwarded": 34,
  "scrapAwarded": 12,
  "corruptionGained": 0,
  "wreckLeft": false
}
```

> **La respuesta es la verdad.** Lo que el cliente calculó durante la run es
> feedback visual; el estado real del jugador es lo que devuelve este endpoint.

**Errores:**

| Código | Cuándo | `error` |
|---|---|---|
| `401` | Token ausente o inválido | `missing bearer token` / `invalid token` |
| `400` | Payload malformado | `invalid <campo>` |
| `405` | Método distinto de POST | `method not allowed` |
| `409` | Ya jugó la seed diaria de hoy | mensaje de Postgres (unique violation) |
| `422` | Falló una validación anti-cheat | ver tabla siguiente |
| `500` | Error de acreditación | mensaje de Postgres |

**Validaciones que devuelven `422`:**

| Mensaje | Regla |
|---|---|
| `run timestamps out of range` | `startedAt + durationMs` fuera de ±`RUN_CLOCK_SKEW_SECONDS` / +6 h |
| `depth not reachable in declared duration` | `depthMeters > (durationMs/1000) × 34` `[TUNE]` |
| `cores exceed collector capacity` | `coresCollected > 20 + 12 × nivel_colector` `[TUNE]` |
| `seed mismatch for daily run` | La `seed` enviada no es la del servidor para esa fecha |

**Efectos:**

- `outcome = "ascended"` → `credit_run()`: suma núcleos, chatarra, corrupción,
  actualiza récord y avanza la cuota semanal
- Cualquier otro outcome con `coresCollected > 0` → se crea un `wreck` abierto
- Cualquier otro outcome con `coresCollected = 0` → la run queda registrada y nada más

---

## RPCs (PostgREST)

`POST /rest/v1/rpc/<nombre>`

### `bootstrap_player`
```json
{ "p_display_name": "Ocho" }
```
Crea perfil + los 4 slots de tabla. Idempotente: si ya existe, renombra.

### `purchase_upgrade`
```json
{ "p_slot": "collector" }
```
Slots: `hull` \| `regulator` \| `keel` \| `collector`.
Costo: `100 × (nivel_destino)²` Núcleos. `[TUNE]`

Errores: `insufficient cores: need N`, `slot already at max level`.

### `claim_wreck`
```json
{ "p_wreck_id": "0f8b…" }
```
Devuelve `{ "cores_awarded": N }`. El recuperador se lleva el 60%; el dueño
original recupera el 20%. No se puede reclamar el naufragio propio.

---

## Lecturas directas (RLS)

| Recurso | Qué devuelve |
|---|---|
| `GET /rest/v1/players?select=*` | Solo el perfil propio |
| `GET /rest/v1/board_upgrades?select=*` | Solo los slots propios |
| `GET /rest/v1/runs?select=*&order=created_at.desc` | Solo las runs propias |
| `GET /rest/v1/wrecks?seed=eq.<seed>&recovered_by=is.null` | Naufragios abiertos de otros |
| `GET /rest/v1/leaderboard_daily?seed_date=eq.<fecha>` | Top de esa seed. No expone `player_id` |

`runs` es **solo lectura** para el cliente: no hay policy de `insert`.

---

## Pendiente

- [ ] Firma HMAC del payload de run además de la validación heurística
- [ ] Rate limiting por jugador en `submit-run`
- [ ] Endpoint de fantasmas (trazo de descenso de otro jugador)
- [ ] Versionado del contrato (`X-AbyssSurge-Client` header)
