# Arquitectura

## Vista general

```
┌─────────────────────────────┐
│      Unity (Android/iOS)    │
│                             │
│  Core ◀── Gameplay ◀── UI   │
│    ▲                        │
│    └── Network              │
└──────────────┬──────────────┘
               │ HTTPS
               ▼
┌─────────────────────────────┐
│         Supabase            │
│                             │
│  Auth ──▶ Edge Functions    │
│             │               │
│             ▼               │
│  Postgres + RLS + RPCs      │
└─────────────────────────────┘
```

**No hay servidor propio.** Toda la lógica autoritativa vive en Edge Functions
(Deno) y funciones de Postgres.

## Decisión central: el cliente no es de fiar

El juego es single-player en su ejecución pero comparte leaderboards,
naufragios y una seed diaria. Eso hace que el estado sea competitivo, y un
cliente móvil es trivialmente modificable.

**Consecuencia:** el cliente puede simular, mostrar y predecir; no puede
acreditar. La única escritura que afecta la economía pasa por `submit-run`,
que valida:

1. Coherencia temporal (`startedAt + durationMs` vs. reloj del servidor)
2. Física (profundidad alcanzable en el tiempo declarado)
3. Capacidad (núcleos ≤ colector equipado)
4. Seed (la del servidor, no la que mandó el cliente)

`runs` no tiene policy de `insert` para `authenticated`. No es una omisión.

## Flujo de una run

```
 Unity                          Supabase
   │
   │  POST /functions/v1/daily-seed
   ├──────────────────────────────────▶ genera/lee daily_seeds
   │◀────────────────────────────────── { date, seed, modifiers }
   │
   │  DeterministicRandom(seed)
   │  → genera el nivel localmente
   │
   │  ═══ run offline, 3–6 min ═══
   │      RunSession simula todo
   │      sin tocar la red
   │
   │  POST /functions/v1/submit-run
   ├──────────────────────────────────▶ valida (4 chequeos)
   │                                     │
   │                                ┌────┴────┐
   │                          ascended?      no
   │                                │         │
   │                        credit_run()   insert wrecks
   │                                │         │
   │◀────────────────────────────────┴─────────┘
   │  { credited, coresAwarded, corruptionGained, wreckLeft }
   │
   │  aplica la respuesta del servidor (no lo que calculó local)
```

La run entera es **offline**. Solo hay dos llamadas de red: al empezar y al
terminar. Eso es deliberado: es un juego móvil, y el jugador va a perder señal
en el subte.

## Determinismo compartido

`Core/DeterministicRandom.cs` (C#, xorshift128) y `_shared/seed.ts`
(TypeScript, SHA-256) son **un mismo algoritmo en dos lenguajes**:

- El servidor deriva la seed: `SHA256(fecha + DAILY_SEED_SALT)` → 16 hex chars
- El cliente siembra el PRNG con esos 16 chars y genera el nivel

Si cambia cualquiera de los dos, la seed diaria deja de producir el mismo nivel
para todos y el leaderboard pierde sentido. **Cambiarlos siempre juntos, y
siempre con una migration que invalide las seeds viejas.**

## Multijugador asíncrono

No hay red en tiempo real. Todo el "multijugador" son escrituras y lecturas de
tablas:

| Feature | Implementación |
|---|---|
| Leaderboard | Vista `leaderboard_daily`, agregada sobre `runs` |
| Naufragios | Tabla `wrecks` + RPC `claim_wreck` |
| Seed diaria | Tabla `daily_seeds` + Edge Function |
| Fantasmas | *(pendiente)* — trazo de descenso en Storage |

## Decisiones y sus porqués

| Decisión | Por qué | Costo aceptado |
|---|---|---|
| Sin SDK oficial de Supabase en Unity | Peso del APK y control sobre el threading | Hay que mantener `AbyssApi` a mano |
| `JsonUtility` en vez de Newtonsoft | Cero dependencias, más rápido en móvil | Sin polimorfismo ni renombrado de campos |
| Lógica de run en C# puro (`RunSession`) | Testeable sin abrir Unity | Duplica reglas que también viven en SQL/TS |
| Validación heurística en vez de replay completo | Un replay server-side de 5 min es caro | Un cheater cuidadoso puede pasar |
| Corrupción irreversible | Es el reloj largo del juego | Un jugador puede arruinarse su propia partida |
| Seed diaria de un solo intento | Hace que el intento importe | Frustra al jugador que crashea |

## Riesgos abiertos

- **`submit-run` sin rate limiting.** Un atacante puede spamear runs válidas
  cortas. Mitigación pendiente.
- **Validación de física con un solo `MAX_DESCENT_MPS`.** No modela el dash ni
  los modificadores diarios; hay margen para inflar profundidad.
- **`RunSession` duplica reglas** que también están en `credit_run()` y en
  `submit-run`. Si divergen, el jugador ve un número y recibe otro.
- **Sin versionado de contrato.** Un cliente viejo con un schema nuevo falla
  de formas poco claras.

## Pendientes

- [ ] Diagrama de estados del `RunSession`
- [ ] ADRs individuales para las decisiones de la tabla de arriba
- [ ] Estrategia de migración de datos entre versiones del juego
- [ ] Plan de observabilidad: qué se loguea y dónde
