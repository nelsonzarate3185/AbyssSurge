# Abyss Surge — Sistemas de juego

> **Fuente:** [Docs/Abyss_Surge_Trama_y_Personajes.pdf](Docs/Abyss_Surge_Trama_y_Personajes.pdf)
> (Nelson Zarate, 27/08/2026).
>
> Tres marcas a lo largo del documento:
> **[PDF]** viene textual del documento fuente · **[TUNE]** es un número
> provisorio que hay que balancear · **[propuesta]** llena un hueco que el PDF
> dejaba abierto.
>
> Cuando este documento y [Supabase/migrations/](Supabase/migrations/) se
> contradigan, **manda el schema**. Cada sección apunta a la tabla que la
> implementa.

## Loop principal

```
  BASE (Ciudadela)              MAZMORRA                    BASE
       │                            │                         │
       ├─ elegís mazmorra ──────────┤                         │
       │  y dificultad              │                         │
       │                     3 pisos + 1 jefe                 │
       │                     combates de 30–60 s              │
       │                            │                         │
       │                            ├─ EXP · oro · esencia ───┤
       │                            │                         │
       │◀── evolucionás poderes ────┴── subís de rango ────────┤
       │    con esencia + oro                                  │
       │                                                       │
       └─ Clan Wars cada 3 días ◀──────────────────────────────┘
```

Cada entrada cuesta **10 de energía [PDF]**, y la energía se regenera con el
tiempo. Eso es lo que define el ritmo del juego: sesiones cortas, varias por
día, con un techo natural.

---

## 1 · Combate **[PDF]**

| | |
|---|---|
| **Perspectiva** | Isométrica (estilo Clash of Clans) |
| **Duración** | 30–60 segundos por combate |
| **Loadout** | 4 poderes activos + 2 pasivos |
| **Categorías** | Magia, defensa, summons, control |

**Mecánica:** los enemigos avanzan. Seleccionás un poder. Esquivás tocando el
lado opuesto. Ganás esencia.

Un solo dedo, sin joystick virtual. La decisión por segundo es *qué poder* y
*hacia qué lado*, no dónde pararte.

### Stats en combate

Los cuatro stats de [`class_archetypes`](Supabase/migrations/007_reference_data.sql),
escalados por el multiplicador del rango:

| Stat | Qué hace |
|---|---|
| **HP** | Cuánto aguanta antes de caer |
| **ATK** | Daño base, multiplicado por el `damage_multiplier` del poder |
| **DEF** | Reducción del daño recibido |
| **VEL** | Frecuencia con la que puede actuar y ventana de esquiva |

> Las fórmulas concretas de daño y de ventana de esquiva **no están definidas**.
> Es lo primero que hace falta prototipar: sin eso, los stats son decorativos.

**Revivir** cuesta 50 gemas y no deja efecto persistente — lo consume la run en
curso. Ver §8.

---

## 2 · Clases

Cuatro arquetipos. Se elige uno al despertar en el Acto I y **no se puede
cambiar**. Detalle completo en [CHARACTER_DESIGN.md](CHARACTER_DESIGN.md).

| Clase | HP | ATK | DEF | VEL | Fortaleza | Debilidad |
|---|---:|---:|---:|---:|---|---|
| **Dark Slayer** | 100 | 12 | 4 | 9 | Daño extremo, velocidad rápida | Muy frágil |
| **Phantom Guard** | 140 | 8 | 8 | 5 | Durabilidad extrema | Daño lento |
| **Abyss Mage** | 90 | 9 | 5 | 10 | AoE devastador, maná ilimitado | Muy frágil |
| **Beast Hunter** | 110 | 11 | 6 | 8 | Equilibrado, escalable, versátil | Sin pico **[propuesta]** |

Stats **[PDF]**. La debilidad del Beast Hunter es propuesta: el PDF listaba
«versátil» como debilidad, se confirmó que es fortaleza, y la clase quedaba sin
costo. «Sin pico» significa que **no saltea encuentros: los juega todos**.

Schema: `class_archetypes`, vista `hunter_stats`.

---

## 3 · Poderes **[PDF]**

Los poderes **no suben de nivel: evolucionan**. Cada evolución es una entrada
distinta del catálogo que apunta a la anterior.

Cadena del Dark Slayer, textual del PDF:

| Tier | Poder | Efecto |
|---|---|---|
| 1 | **Golpe Sombra** | 1.0× daño |
| 2 | **Cortadura Abismo** | 1.8× + crítico |
| 3 | **Tornada Oscura** | 2.5× en AoE |
| 4 | **Invocación Espectros** | Summon |

Evolucionar requiere **desafío especial + esencia + oro [PDF]**, más el rango
mínimo del poder.

**El poder anterior no se pierde.** Evolucionar *amplía* el loadout disponible
en vez de reemplazarlo — así el jugador de tier 4 sigue pudiendo equipar el
tier 1 si le conviene para un encuentro.

> Las cadenas de **Phantom Guard**, **Abyss Mage** y **Beast Hunter** no están
> diseñadas. Hoy tienen solo un tier 1 placeholder para que
> `bootstrap_hunter()` funcione.

Schema: `powers`, `hunter_powers`, `power_challenges`, RPC `evolve_power()`.

---

## 4 · Mazmorras **[PDF]**

Estructura fija: **3 pisos + 1 jefe**. Costo: **10 de energía**.

### Tipos

| Tipo | Para qué |
|---|---|
| **Historia** | Una por acto. Completarla cierra el acto y avanza la narrativa |
| **Grind** | EXP, oro y esencia. Repetible |
| **Despertar** | Los desafíos especiales que habilitan evoluciones de poder |
| **Clan** | Requiere pertenecer a un clan. Alimenta las Clan Wars |

### Dificultades

| Dificultad | Enemigos | Recompensa | Rango mínimo |
|---|---:|---:|---|
| **Normal** | ×1.00 | ×1.00 | E |
| **Hard** | ×1.60 | ×1.80 | C **[TUNE]** |
| **Imposible** | ×2.75 | ×3.50 | A **[TUNE]** |

Los multiplicadores son `[TUNE]`: el PDF nombra las tres dificultades pero no
las cuantifica.

Schema: `dungeons`, `difficulty_modifiers`, `dungeon_sessions`, `dungeon_runs`.

---

## 5 · Energía **[propuesta]**

El PDF fija el costo (10 por mazmorra) pero no el techo ni la regeneración.

| Constante | Valor | Dónde se tunea |
|---|---:|---|
| Energía máxima | 50 **[TUNE]** | `game_settings.energy_max` |
| Regeneración | 1 punto / 6 min **[TUNE]** | `game_settings.energy_regen_minutes` |
| Lleno desde cero | 5 h | — |
| Mazmorras con el tanque lleno | 5 | — |

**No hay job de regeneración.** `hunters.energy` guarda el último valor
materializado y `energy_updated_at` cuándo se materializó; la energía vigente
se calcula al leer:

```
vigente = min(máximo, energy + minutos_transcurridos / 6)
```

Al gastar se **preserva el avance parcial** hacia el próximo punto. Sin eso,
gastar energía reiniciaría el timer y el jugador perdería progreso invisible
cada vez que entra a una mazmorra.

Schema: `current_energy()`, `spend_energy()`, `refund_energy()`.

---

## 6 · Rangos y progresión **[PDF]** + **[propuesta]**

Ocho rangos: **E → D → C → B → A → S → SS → SSS**

Al subir: suben las stats base, se desbloquean mazmorras nuevas, y **el aura
crece y se vuelve más oscura [PDF]**.

| Rango | EXP acumulada | Stats | Aura (escala / oscuridad) |
|---|---:|---:|---|
| E | 0 | ×1.00 | 1.00 / 0.00 |
| D | 1 000 | ×1.25 | 1.15 / 0.10 |
| C | 3 500 | ×1.55 | 1.30 / 0.22 |
| B | 9 000 | ×1.90 | 1.50 / 0.36 |
| A | 20 000 | ×2.35 | 1.75 / 0.52 |
| S | 45 000 | ×2.90 | 2.00 / 0.68 |
| SS | 100 000 | ×3.60 | 2.35 / 0.85 |
| SSS | 250 000 | ×4.50 | 2.80 / 1.00 |

Toda la tabla es **[TUNE]**: el PDF dice que las stats suben, no cuánto.

**El aura es dato, no lógica.** Unity lee `aura_scale` y `aura_darkness` y los
aplica; no calcula nada. Objetivo de legibilidad: **leer el rango de otro
jugador de un vistazo, sin UI**.

### Dónde cae cada rango en la campaña **[propuesta]**

- **E → S** es la campaña (Actos I–VI)
- **C** es el rango de Lyra, y el único con un beat propio: su Prueba de Ascenso
- **SS** es post-campaña: abre *La Cicatriz*, mazmorras que dependen del final
  que elegiste
- **SSS** requiere SS + los cuatro arcos de personaje cerrados, y desbloquea el
  quinto final

Ver [STORY.md](STORY.md).

Schema: `rank_tiers`, promoción automática dentro de `award_dungeon_run()`.

---

## 7 · Economía

| Moneda | De dónde sale | En qué se gasta |
|---|---|---|
| **Oro** | Mazmorras | Evolución de poderes |
| **Esencia** | Combate y mazmorras | Evolución de poderes |
| **Gemas** | Compra con dinero real | Conveniencia y cosmética — §8 |

Costo de evolución: `desafío + esencia + oro`, definido por poder en el catálogo.

**Nada se acredita en el cliente.** Toda suma de EXP, oro, esencia o rango pasa
por `award_dungeon_run()` con `service_role`, en una sola transacción. Ver §11.

Schema: `hunters.gold / essence / gems`, `gem_ledger`.

---

## 8 · Monetización **[PDF]**

### Paquetes de gemas

| Paquete | Precio USD | Precio PYG |
|---|---:|---:|
| 100 gemas | $0.99 | ₲7.000 **[TUNE]** |
| 500 gemas | $4.99 | ₲35.000 **[TUNE]** |
| 1200 gemas | $9.99 | ₲70.000 **[TUNE]** |

Los precios en USD son **[PDF]** y sirven para App Store / Google Play. Los de
PYG son **placeholder**: MercadoPago Paraguay cobra en guaraníes y todavía no
hay una decisión comercial sobre esos montos.

### En qué se gastan

| Uso | Gemas | Tipo |
|---|---:|---|
| Recarga de energía | 10 | Conveniencia |
| Revivir en batalla | 50 | Conveniencia |
| Skin cosmética | 500 | Cosmética |
| Battle Pass mensual | 1000 | Cosmética |

### Sin pay2win, como constraint

> «Cosmética pura. Jugadores F2P pueden ganar vs premium. No hay ventaja de
> poder comprando.» **[PDF §8]**

Ese compromiso está codificado en el schema, no en una convención:

```sql
constraint gem_sinks_no_power check (
  is_cosmetic or id in ('energy_refill', 'revive')
)
```

Agregar un sink que dé stats o daño **falla al insertarlo**. No depende de que
alguien se acuerde de la regla en dos años.

Schema: `gem_products`, `gem_sinks`, `purchases`, `gem_ledger`, `entitlements`.
Integración: [Docs/API/](Docs/API/README.md).

---

## 9 · Clanes y Clan Wars **[PDF]**

| | |
|---|---|
| **Miembros** | Máximo 50 |
| **Roles** | Líder · Capitanes · Oficiales · Miembros |
| **Ciudadela** | Con un defensor designado |
| **Clan Wars** | Cada 3 días |

Reglas de gobierno implementadas:

- Un cazador pertenece **a un solo clan** (es la PK de `clan_members`)
- El líder **no puede irse sin transferir** el liderazgo
- Solo el líder asigna roles; líder y capitanes designan al defensor
- Un clan no puede estar en dos guerras activas a la vez

> **Falta el scheduler.** Las tablas de `clan_wars` existen pero nada arma las
> guerras cada 3 días. Hace falta un job (pg_cron o Edge Function) con criterio
> de emparejamiento.

Schema: `clans`, `clan_members`, `clan_wars`, `clan_war_battles`.

---

## 10 · La narrativa como sistema

Los seis actos no son cinemáticas sueltas: cada uno tiene **una mazmorra de
historia** con su rango mínimo. Completarla cierra el acto.

| Acto | Mazmorra | Rango |
|---|---|---|
| I · El Llamado del Abismo | `story_01_llamado` | E |
| II · Clanes y Competencia | `story_02_clanes` | D |
| *Interludio · La Prueba de Lyra* **[propuesta]** | *(pendiente)* | C |
| III · Misterios en Profundidades | `story_03_misterios` | B |
| IV · El Ritual Oscuro | `story_04_ritual` | A |
| V · Verdad Abismal | `story_05_verdad` | S |
| VI · Nuevo Orden | `story_06_nuevo_orden` | S |

El rango mínimo es el gate: no se avanza la historia sin haber jugado. Eso
liga la narrativa al grind sin que haga falta un sistema aparte.

Schema: `dungeons.story_act`, `story_progress`, `hunters.story_act`.

---

## 11 · Autoridad del servidor

El juego es single-player en ejecución pero comparte clanes, guerras y
leaderboards. Un cliente móvil es trivialmente modificable, así que:

> **El cliente no acredita nada.**

Tres capas, en orden:

1. **RLS** decide qué filas ve cada jugador
2. **Grants por columna** deciden qué columnas puede escribir — RLS no filtra
   columnas, y sin el grant la policy de `update` sobre `hunters` dejaría al
   jugador editarse el oro
3. **Edge Functions** validan la lógica de juego antes de acreditar

En todo el schema el cliente puede escribir **exactamente dos columnas**:
`hunters.display_name` y `hunter_powers.loadout_slot`.

### Flujo de una mazmorra

```
enter-dungeon              ← cobra la energía ACÁ
  ├─ valida rango vs. mazmorra y dificultad
  ├─ si es mazmorra de clan, valida membresía
  └─ abre dungeon_sessions (vence en 30 min)

  ═══ combate offline ═══

complete-dungeon-run
  ├─ la sesión es del caller y sigue abierta
  ├─ coherencia: pisos ≤ los de la mazmorra, jefe requiere pisos completos
  ├─ tiempo: ni instantáneo ni fuera de la ventana
  └─ award_dungeon_run() ← una transacción
```

La energía se cobra **al entrar**. Si se cobrara al salir, un cliente
modificado jugaría gratis; si no se cobrara nada al entrar, el jugador podría
gastar un minuto y comerse un rechazo por falta de energía.

Contrato completo: [Docs/API/](Docs/API/README.md).

---

## Pendientes, por prioridad

**Bloqueante para prototipar**
- [ ] Fórmula de daño y ventana de esquiva — sin eso los stats no significan nada
- [ ] Cliente Unity: sigue siendo el del scaffold equivocado

**Diseño sin resolver**
- [ ] Cadenas de poderes de Phantom Guard, Abyss Mage y Beast Hunter
- [ ] Enemigos: el PDF no menciona ninguno
- [ ] Curvas de EXP y multiplicadores de dificultad (hoy todo `[TUNE]`)
- [ ] Mazmorra del Interludio de Lyra

**Backend**
- [ ] Aplicar las migrations y arreglar lo que falle
- [ ] Scheduler de Clan Wars + criterio de emparejamiento
- [ ] Job que cierre compras `pending` viejas y sesiones vencidas

**Negocio**
- [ ] Precios reales en PYG
- [ ] Contenido del Battle Pass y catálogo de skins
