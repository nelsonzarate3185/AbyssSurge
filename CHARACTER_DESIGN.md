# Abyss Surge — Diseño de personajes

> **Fuente:** [Docs/Abyss_Surge_Trama_y_Personajes.pdf](Docs/Abyss_Surge_Trama_y_Personajes.pdf)
> (Nelson Zarate, 27/08/2026). Este documento transcribe y estructura ese PDF.
> Reemplaza por completo el borrador especulativo anterior.

## Clases jugables

Cuatro arquetipos balanceados. El jugador elige uno al despertar (Acto I).

| Clase | HP | ATK | DEF | VEL | Fortaleza | Debilidad |
|---|---:|---:|---:|---:|---|---|
| **Dark Slayer** | 100 | 12 | 4 | 9 | Daño extremo, velocidad rápida | Muy frágil |
| **Phantom Guard** | 140 | 8 | 8 | 5 | Durabilidad extrema | Daño lento |
| **Abyss Mage** | 90 | 9 | 5 | 10 | AoE devastador, maná ilimitado | Muy frágil |
| **Beast Hunter** | 110 | 11 | 6 | 8 | Equilibrado, escalable | Versátil |

Lectura del balance: **Phantom Guard** es el único tanque real (+40 HP sobre la
media, DEF duplicada) y paga con la peor velocidad. **Abyss Mage** y
**Dark Slayer** comparten fragilidad pero por razones distintas — el Mage tiene
el HP más bajo del juego, el Slayer la DEF más baja. **Beast Hunter** no tiene
pico: es la clase de entrada.

> **Nota:** en el PDF, "Versátil" figura como *debilidad* del Beast Hunter.
> Hay que decidir si eso significa "no sobresale en nada" o si es un error de
> tipeo y va en la columna de fortalezas.

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
- [ ] Diseño visual del aura para los 8 rangos
- [ ] ¿"Versátil" es fortaleza o debilidad del Beast Hunter?
- [ ] Curva de stats por rango — el PDF dice que suben, no cuánto
- [ ] Retratos y expresiones de los 4 NPCs
- [ ] ¿Los NPCs tienen mecánica además de narrativa? (Lyra como vendor, Kael
      como duelo recurrente, etc.)
- [ ] Diseño de los enemigos de mazmorra — el PDF no los menciona

Specs de export y assets: [Design/Characters/README.md](Design/Characters/README.md)
