# AbyssSurge — Sistemas de juego

> ## ⚠️ ESTE DOCUMENTO DESCRIBE OTRO JUEGO
>
> Todo lo que sigue es un borrador especulativo escrito **antes** de que
> apareciera [Docs/Abyss_Surge_Trama_y_Personajes.pdf](Docs/Abyss_Surge_Trama_y_Personajes.pdf),
> y describe un roguelite de descenso vertical que **no es Abyss Surge**.
>
> El juego real es un **RPG estratégico mobile** (Clash of Clans + Solo Leveling):
> combate isométrico de 30–60 s, mazmorras de 3 pisos + jefe, rangos E→SSS,
> clanes de hasta 50 miembros con Clan Wars, energía y gemas.
> Ver [STORY.md](STORY.md) y [CHARACTER_DESIGN.md](CHARACTER_DESIGN.md), que ya
> están reescritos desde el PDF.
>
> **No implementes nada de este archivo.** Queda solo para no perder el trabajo
> hasta que se reescriba. Lo mismo aplica al schema de
> [Supabase/migrations/](Supabase/migrations/), a los scripts de
> [Unity/Assets/Scripts/](Unity/Assets/Scripts/) y a [Docs/](Docs/): están
> construidos sobre esta premisa equivocada.

---

## Sistemas del juego real (del PDF)

| Sistema | Resumen |
|---|---|
| **Combate** | Isométrico, 30–60 s. Los enemigos avanzan; seleccionás poder; esquivás tocando el lado opuesto. Ganás esencia |
| **Loadout** | 4 poderes activos + 2 pasivos (magia, defensa, summons, control) |
| **Mazmorras** | 3 pisos + 1 jefe. Tipos: Historia, Grind, Despertar, Clan. Dificultades: Normal / Hard / Imposible. Costo: 10 energía |
| **Rangos** | E → D → C → B → A → S → SS → SSS. Suben stats, desbloquean mazmorras, cambian el aura |
| **Poderes** | Evolucionan (no suben de nivel). Requieren desafíos especiales + esencia + oro |
| **Clanes** | Máx. 50 miembros. Roles: Líder, Capitanes, Oficiales. Ciudadela con defensor. Clan Wars cada 3 días |
| **Monedas** | Oro y esencia (juego) · Gemas (premium) |
| **Monetización** | Gemas: 100G=$0.99 / 500G=$4.99 / 1200G=$9.99. Usos: 10G refill energía, 50G revivir, 500G skins, 1000G Battle Pass mensual |
| **Filosofía** | **Sin pay2win.** Cosmético puro; un F2P puede ganarle a un premium |
| **Pagos** | MercadoPago Paraguay |

Esto es un índice, no una especificación. Falta desarrollarlo: curvas de EXP por
rango, regeneración de energía, fórmulas de daño, matchmaking de Clan Wars,
economía de esencia/oro.

---

## Borrador descartado (roguelite de descenso)

## Género y loop

**Roguelite de descenso vertical, sesiones cortas, control táctil de un dedo.**

```
BASE (Ancla)  ──▶  DESCENSO (run)  ──▶  EXTRACCIÓN  ──▶  ASCENSO  ──▶  BASE
     ▲                                                        │
     └────────────────── meta-progresión ─────────────────────┘
```

Duración objetivo de una run: **3–6 minutos**. Es un juego móvil: tiene que
sobrevivir a que te interrumpan.

## 1. Descenso (core loop)

El Surfista cae. La gravedad es constante; el jugador controla **inclinación**
y **frenado**.

| Input | Acción |
|---|---|
| Arrastrar horizontal | Inclinar la tabla (deriva lateral) |
| Mantener presionado | Frenar — consume Oxígeno más rápido |
| Doble tap | *Surge Dash* — impulso vertical, consume 1 carga |
| Soltar todo | Caída libre — máxima velocidad, mínimo control |

**Tensión de diseño:** bajar rápido da más profundidad (más recompensa) pero
menos tiempo de reacción. Bajar lento es seguro pero el Oxígeno no alcanza.

## 2. Recursos de run

| Recurso | Rol | Se agota por |
|---|---|---|
| **Oxígeno** | Timer de la run | Tiempo + frenado + daño |
| **Integridad** | HP de la tabla | Colisiones, Despiertos |
| **Cargas de Surge** | Recurso de habilidad | Dash, escudo, pulso |
| **Núcleos** | Botín — moneda de la run | *(se pierden si no ascendés)* |

**Regla clave:** los Núcleos solo se acreditan al **completar el ascenso**.
Morir a 900 m con la bolsa llena no te da nada. Eso es el juego.

## 3. Profundidad y zonas

La profundidad es la métrica de progreso dentro de la run.

| Tramo | Profundidad | Presión | Multiplicador de botín |
|---|---|---|---|
| Plataforma | 0–200 m | 1.0× | 1.0× |
| Termoclina | 200–600 m | 1.4× | 1.8× `[TUNE]` |
| Zona muerta | 600–1200 m | 2.1× | 3.2× `[TUNE]` |
| La Grieta | 1200 m+ | 3.0× | 5.0× `[TUNE]` |

La **Presión** multiplica el consumo de Oxígeno y el daño recibido.

## 4. Ascenso

Cuando el jugador decide subir (o se queda sin profundidad disponible), la run
se invierte: la cámara sube, los patrones de enemigo cambian, **no se puede
frenar**. El ascenso es un minijuego de esquivar puro.

Costo de ascenso: `oxígeno_requerido = profundidad_actual × 0.4` `[TUNE]`

Esto obliga a la decisión central: *un tramo más* vs. *volver con lo que tengo*.

## 5. Meta-progresión (entre runs)

### Tabla (Board)
Se mejora con **Chatarra** (drop común). Ramas:
- **Casco** — Integridad máxima
- **Regulador** — Oxígeno máximo y eficiencia bajo presión
- **Quilla** — control lateral y velocidad de deriva
- **Colector** — capacidad de Núcleos y radio de recolección

### Corrupción (Corruption)
Contador **permanente** que sube al usar Surge y al descender bajo 600 m.

| Nivel | Efecto positivo | Efecto negativo |
|---|---|---|
| 0–25 | — | — |
| 26–50 | +10% velocidad de descenso | Visión periférica reducida |
| 51–75 | Ver Núcleos a través del terreno | Oxígeno máximo −15% |
| 76–99 | Dash gratis cada 30 s | Enemigos ambientales te ignoran… y los Despiertos te siguen |
| 100 | **Punto de no retorno narrativo** | Se bloquea el final 1 |

La Corrupción **no se puede bajar con recursos**, solo con decisiones narrativas
concretas. Es el reloj largo del juego.

## 6. Economía

| Moneda | Fuente | Gasto |
|---|---|---|
| **Núcleos** | Extracción en run | Upgrades de tabla, desbloqueos de zona |
| **Chatarra** | Drop común, desguace | Reparaciones, consumibles |
| **Crédito de Ancla** | Cuotas del Consorcio | Progresión narrativa, acceso a facciones |

**Sin moneda premium en el diseño base.** Si más adelante se monetiza, que sea
cosmético sobre la tabla — nunca sobre Oxígeno, Integridad ni Corrupción.

## 7. Cuotas (presión narrativa como sistema)

El Consorcio asigna una cuota semanal de Núcleos.

- Cumplirla → Crédito de Ancla, acceso a mejor equipo
- Fallarla → pérdida de acceso a zonas, avanza el arco de los Sin Lastre

La cuota **escala más rápido que la capacidad del jugador**. Es intencional:
el sistema está diseñado para volverse imposible. Ese es el Acto II.

## 8. Multijugador asíncrono (Supabase)

No hay PvP en tiempo real. Sí hay:

- **Fantasmas** — el trazo de descenso de otro jugador en la misma seed
- **Leaderboard** por profundidad y por Núcleos extraídos, semanal
- **Naufragios** — donde otro jugador murió aparece su tabla; recuperarla te da
  parte de su botín y le envía a él una notificación (y una fracción de recompensa)
- **Seed diaria** — misma run para todos, un intento

Todo esto es escritura/lectura de tablas + Edge Functions. Ver
[Supabase/README.md](Supabase/README.md) y [Docs/Architecture/](Docs/Architecture/).

## 9. Anti-cheat (mínimo viable)

El cliente **no** decide recompensas. El cliente envía un resumen de run firmado;
la Edge Function `submit-run` valida:

- Profundidad alcanzable dado el tiempo transcurrido (`v_max` por tramo)
- Núcleos ≤ capacidad del colector equipado
- Timestamps monotónicos y coherentes con la seed del día

Rechazo → la run no se acredita. Ver [Docs/API/](Docs/API/).

## Pendientes

- [ ] Curva de Oxígeno vs. profundidad — hace falta prototipo jugable
- [ ] Cuántos enemigos distintos por tramo (target: 3 por tramo)
- [ ] ¿La Corrupción persiste en NG+?
- [ ] Definir seed determinista compartida cliente/servidor
