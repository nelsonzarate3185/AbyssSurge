# Contrato de API

Base URL: `https://ocmroiupftpbsukuqvyu.supabase.co`
Project ref: `ocmroiupftpbsukuqvyu`

Headers en toda llamada:

```http
apikey: <SUPABASE_ANON_KEY>
Authorization: Bearer <access_token>
Content-Type: application/json
```

La `anon key` es pública por diseño — lo que protege es RLS. La
`service_role` key **nunca** sale del servidor.

---

## Edge Functions

### `POST /functions/v1/enter-dungeon`

Abre un intento de mazmorra. **Acá se cobra la energía.**

**Request:**
```json
{ "dungeonId": "grind_fisura_menor", "difficulty": "normal" }
```

`difficulty`: `normal` | `hard` | `impossible` (default `normal`)

**Response `200`:**
```json
{
  "sessionId": "9f2c…",
  "dungeonId": "grind_fisura_menor",
  "difficulty": "normal",
  "rankAtEntry": "C",
  "energySpent": 10,
  "energyRemaining": 32,
  "startedAt": "2026-08-27T14:02:11.000Z",
  "expiresAt": "2026-08-27T14:32:11.000Z"
}
```

Guardá el `sessionId`: sin él no se puede cerrar el intento.

**Errores:**

| Código | Cuándo |
|---|---|
| `401` | Token ausente o inválido |
| `400` | `invalid dungeonId` / `invalid difficulty` |
| `402` | `insufficient energy: have N, need M` |
| `403` | `rank X required for this dungeon` · `rank X required for hard` · `clan membership required` |
| `404` | Mazmorra inexistente, o el cazador no existe todavía (llamar `bootstrap_hunter` primero) |
| `409` | `a dungeon session is already open` — hay un intento sin cerrar |

En el `409` la energía **se devuelve**: el cobro y la apertura de sesión no son
atómicos, así que un doble tap no cuesta 10 de energía.

---

### `POST /functions/v1/complete-dungeon-run`

Cierra el intento y acredita.

**Request:**
```json
{
  "sessionId": "9f2c…",
  "floorsCleared": 3,
  "bossDefeated": true,
  "outcome": "cleared",
  "durationMs": 184000
}
```

| Campo | Tipo | Notas |
|---|---|---|
| `sessionId` | string | El de `enter-dungeon` |
| `floorsCleared` | int ≥ 0 | Máximo: los pisos de la mazmorra (3) |
| `bossDefeated` | bool | Requiere haber limpiado todos los pisos |
| `outcome` | enum | `cleared` \| `failed` \| `abandoned` |
| `durationMs` | int > 0 | Duración real del intento |

**Response `200`:**
```json
{
  "runId": "0f8b…",
  "outcome": "cleared",
  "expAwarded": 150,
  "goldAwarded": 400,
  "essenceAwarded": 25,
  "hunter": { "rank": "B", "exp": 9150, "gold": 5400, "essence": 825, "story_act": 3 }
}
```

> **La respuesta es la verdad.** Lo que el cliente calculó durante el combate
> es feedback visual. El `hunter` que vuelve acá ya incluye una promoción de
> rango si la hubo.

**Errores:**

| Código | Cuándo |
|---|---|
| `401` | Token inválido |
| `400` | Payload malformado |
| `403` | `session belongs to another hunter` |
| `404` | `session not found` |
| `409` | `session already consumed` |
| `410` | `session expired` — pasaron más de 30 min. La energía **no** se devuelve |
| `422` | Falló una validación de coherencia (abajo) |

**Validaciones que devuelven `422`:**

| Mensaje | Regla |
|---|---|
| `floorsCleared exceeds dungeon floors` | `floorsCleared > dungeons.floors` |
| `dungeon has no boss` | `bossDefeated` en una mazmorra sin jefe |
| `boss defeated without clearing all floors` | Jefe sin los 3 pisos |
| `cleared requires defeating the boss` | `outcome = cleared` sin matar al jefe |
| `duration too short for the reported progress` | `< 20 s` por encuentro `[TUNE]` |
| `duration inconsistent with session window` | Más larga que la ventana de la sesión |

**Efectos de `outcome = "cleared"`** (todo en una transacción):

1. Se consume la sesión
2. Se registra la run con las recompensas × multiplicador de dificultad
3. Suma EXP, oro y esencia al cazador
4. **Promueve de rango** si la EXP alcanza el siguiente `rank_tiers`
5. Si era mazmorra de historia, cierra el acto y avanza `story_act`

Un `failed` o `abandoned` registra la run con recompensas en 0. La energía ya
se gastó al entrar y no vuelve.

---

## RPCs

`POST /rest/v1/rpc/<nombre>`

### Onboarding

#### `bootstrap_hunter`
```json
{ "p_display_name": "Kael", "p_class": "dark_slayer" }
```
Clases: `dark_slayer` | `phantom_guard` | `abyss_mage` | `beast_hunter`.

Crea el cazador con energía llena y le da el poder tier 1 de su clase equipado
en el slot 1. Idempotente en el nombre. **La clase no se puede cambiar después.**

#### `current_energy`
```json
{ "p_hunter_id": "<uuid>" }
```
Devuelve un entero. Leer `hunters.energy` directo da un valor viejo: no incluye
la regeneración acumulada.

### Poderes

#### `evolve_power`
```json
{ "p_power_id": "ds_cortadura_abismo" }
```
Requiere: el poder anterior de la cadena, el desafío especial si lo pide, el
rango mínimo, y esencia + oro suficientes.

El poder anterior **no se pierde** — evolucionar amplía el loadout disponible.

Errores: `missing prerequisite power X`, `challenge X not completed`,
`rank X required`, `insufficient resources: need N essence, M gold`,
`power already unlocked`, `power belongs to another class`.

### Gemas

#### `spend_gems`
```json
{ "p_sink_id": "energy_refill" }
```

| Sink | Gemas | Efecto |
|---|---:|---|
| `energy_refill` | 10 | Energía al máximo |
| `revive` | 50 | Sin efecto persistente: lo consume la run en curso |
| `skin_basic` | 500 | Entitlement permanente |
| `battle_pass` | 1000 | Entitlement por 30 días |

Devuelve el saldo de gemas restante. Todo movimiento queda en `gem_ledger`.

### Clanes

| RPC | Body | Notas |
|---|---|---|
| `create_clan` | `{ p_name, p_tag, p_description }` | El tag se normaliza a mayúsculas. 2–5 caracteres `[A-Z0-9]` |
| `join_clan` | `{ p_clan_id }` | Valida cupo de 50, rango mínimo y que esté abierto |
| `leave_clan` | `{}` | El líder debe transferir el liderazgo primero |
| `set_clan_role` | `{ p_hunter_id, p_role }` | Solo el líder. Asignar `leader` transfiere y degrada al saliente a `captain` |
| `set_clan_defender` | `{ p_hunter_id }` | Líder y capitanes |

Roles: `leader` | `captain` | `officer` | `member`.

---

## Lecturas directas (RLS)

| Recurso | Qué devuelve |
|---|---|
| `GET /rest/v1/hunters?select=*` | Solo el perfil propio |
| `GET /rest/v1/hunter_stats?select=*` | Stats efectivos (base × rango) + datos del aura |
| `GET /rest/v1/hunter_powers?select=*,powers(*)` | Poderes propios con su definición |
| `GET /rest/v1/dungeons?select=*&order=sort_order` | Catálogo completo |
| `GET /rest/v1/powers?class=eq.dark_slayer` | Catálogo de poderes de una clase |
| `GET /rest/v1/dungeon_runs?order=created_at.desc` | Historial propio |
| `GET /rest/v1/clans?is_open=eq.true` | Todos los clanes — es buscable a propósito |
| `GET /rest/v1/clan_members?select=*` | Solo los del clan propio |
| `GET /rest/v1/gem_products?select=*` | Paquetes activos |
| `GET /rest/v1/gem_ledger?order=created_at.desc` | Movimientos de gemas propios |

**Escritura desde el cliente:** solo dos columnas en todo el schema.

| Recurso | Columna |
|---|---|
| `PATCH /rest/v1/hunters?id=eq.<uid>` | `display_name` |
| `PATCH /rest/v1/hunter_powers?...` | `loadout_slot` (1–4 activos, 5–6 pasivos) |

Cualquier otra columna es rechazada por el grant, no por la policy.

---

## Pendiente

- [ ] MercadoPago Paraguay: `create-payment` + `payment-webhook`, productos en PYG
- [ ] Endpoints de Clan Wars (declarar, atacar, resolver)
- [ ] Leaderboards
- [ ] Rate limiting en `enter-dungeon`
- [ ] Versionado del contrato (`X-AbyssSurge-Client`)
