# Abyss Surge — Diseño de personajes

> **Fuente:** [Docs/Abyss_Surge_Trama_y_Personajes.pdf](Docs/Abyss_Surge_Trama_y_Personajes.pdf)
> (Nelson Zarate, 27/08/2026). Stats, roles y nombres son del PDF.
> Lo marcado **[propuesta]** llena huecos que el documento dejaba abiertos.

## Clases jugables

Cuatro arquetipos balanceados. El jugador elige uno al despertar (Acto I).

| Clase | HP | ATK | DEF | VEL | Fortaleza | Debilidad |
|---|---:|---:|---:|---:|---|---|
| **Dark Slayer** | 100 | 12 | 4 | 9 | Daño extremo, velocidad rápida | Muy frágil |
| **Phantom Guard** | 140 | 8 | 8 | 5 | Durabilidad extrema | Daño lento |
| **Abyss Mage** | 90 | 9 | 5 | 10 | AoE devastador, maná ilimitado | Muy frágil |
| **Beast Hunter** | 110 | 11 | 6 | 8 | Equilibrado, escalable, versátil | Sin pico |

Lectura del balance: **Phantom Guard** es el único tanque real (+40 HP sobre la
media, DEF duplicada) y paga con la peor velocidad. **Abyss Mage** y
**Dark Slayer** comparten fragilidad pero por razones distintas — el Mage tiene
el HP más bajo del juego, el Slayer la DEF más baja.

### La debilidad del Beast Hunter — **[propuesta]**

Confirmado que «versátil» es **fortaleza**, la clase quedaba sin debilidad. Su
costo sale de sus propios números: es segundo en todo y primero en nada.

> **Sin pico** — no saltea encuentros, los juega todos.

Las otras tres clases tienen una salida rápida: el Dark Slayer revienta al jefe
antes de que actúe, el Phantom Guard ignora una mecánica entera aguantándola, el
Abyss Mage limpia la sala de un golpe. El Beast Hunter no tiene ninguna: cada
piso se pelea completo.

**Por qué eso duele de verdad:** con combates de 30–60 s y 10 de energía por
mazmorra, el tiempo por encuentro es un costo real. El Beast Hunter llega a
todos lados y a ninguno primero. Nunca se traba — y nunca abre un atajo.

## NPCs principales

### LYRA — La Mentora
**Cazadora retirada · C-rank**

Te encuentra en el Acto I, después del ataque a tu aldea, y te enseña qué son
los Cazadores. No es solo tutorial: **descubre los secretos junto con vos**, no
antes que vos. En el Acto IV es quien revela la existencia de la Gildía Oscura.

Es C-rank: **está muy por debajo del jugador en la segunda mitad del juego**.
Eso es material dramático, no un descuido — la mentora se queda atrás.

### KAEL — Rival / Espejo
**Cazador Despierto · igual a vos**

Aparece en el Acto II como rival. Comparten una **conexión extraña con el
Abismo** que ninguno de los dos entiende.

Es literalmente tu espejo: mismo origen, misma condición. Todo lo que el Acto V
revela sobre vos aplica también a él. Es capturado en el Acto IV.

**Cómo cierra su arco — [propuesta]:** no es un rehén, es la **prueba de
concepto**. Vor quiere esclavizar al Abismo y Kael está hecho de Abismo. Cuando
llegás a rescatarlo ya está atado —lúcido, entero— y **no quiere que lo
liberes**. Nadie lo quebró: le mostraron que el vínculo se sostiene sin
devorarte, y eligió quedarse.

En el Acto V no pelea contra vos. Mira. Es el argumento de Vor parado al lado de
Vor, y es tu amigo, y tiene razón en la mitad de lo que dice.

Cada final le da un destino distinto — ver [STORY.md](STORY.md).

### VEX — Voz del Abismo
**Inteligencia cósmica**

Te habla **en sueños**, desde el Acto II. Guía misteriosa.

Nunca se aclara si dice la verdad. Dado el giro del Acto V —sos parte del
Abismo— Vex no te está guiando desde afuera: te está hablando desde adentro.

### VOR — Antagonista
**Líder de la Gildía Oscura · S-rank**

Busca **esclavizar al Abismo**, no destruirlo. Boss final del Acto V.

El conflicto es **ideológico**. Vor y el jugador están resolviendo el mismo
problema por caminos distintos, y el juego no le da un motivo barato.

## Progresión visual del jugador

Ocho rangos: **E → D → C → B → A → S → SS → SSS**

La campaña va de **E a S**. **SS** y **SSS** son post-campaña: SS abre *La
Cicatriz* (mazmorras que dependen del final elegido) y SSS desbloquea el
**Umbral**, el quinto final. Nada se pierde por elegir «mal»: el final secreto
se gana jugando, no se bloquea. **[propuesta]**

**C es el rango de Lyra**, y por eso es el único con un beat propio: la Prueba
de Ascenso que ella administra, donde por única vez quedan a la par. **[propuesta]**

Al subir de rango:
- Suben las estadísticas base
- Se desbloquean mazmorras nuevas
- **El personaje cambia visualmente: el aura crece y se vuelve más oscura**

El aura es el indicador de progresión más visible del juego. Un jugador tiene
que poder leer el rango de otro **de un vistazo**, sin UI.

## Evolución de poderes

Los poderes no se mejoran con niveles: **evolucionan**, y cada salto cambia lo
que el poder hace.

Cadena de ejemplo (Dark Slayer):

| Etapa | Poder | Efecto |
|---|---|---|
| 1 | **Golpe Sombra** | 1.0× daño |
| 2 | **Cortadura Abismo** | 1.8× daño + crítico |
| 3 | **Tornada Oscura** | 2.5× daño en AoE |
| 4 | **Invocación Espectros** | Summon |

Cada evolución requiere **desafíos especiales + esencia + oro**. No se compra
con gemas — ver la filosofía de monetización en [GAME_MECHANICS.md](GAME_MECHANICS.md).

Loadout en combate: **4 poderes activos + 2 pasivos**. Categorías: magia,
defensa, summons, control.

## Pendientes

- [ ] Cadenas de evolución de las otras 3 clases (solo está la del Slayer)
- [ ] Curva de stats por rango — el PDF dice que suben, no cuánto
- [ ] Retratos y expresiones de los 4 NPCs (hoy hay siluetas placeholder)
- [ ] Condición concreta que "cierra" el arco de cada NPC, para desbloquear SSS
- [ ] Diseño de los enemigos de mazmorra — el PDF no los menciona

Specs de export y assets: [Design/Characters/README.md](Design/Characters/README.md)
