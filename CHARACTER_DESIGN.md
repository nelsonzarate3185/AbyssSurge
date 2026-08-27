# AbyssSurge — Diseño de personajes

> **Borrador v0.** Stats en escala 1–10 relativa, no valores finales.

## Jugador — El Surfista

El avatar es **mudo y personalizable**. La identidad la aporta la tabla, no la cara.

**Silueta:** traje presurizado ajustado, casco con visor de una sola franja
luminosa. La franja **cambia de color con la Corrupción**: cian (0) → verde
(50) → ámbar (75) → blanco (100). Es el HUD de estado más importante del juego
y está en el personaje, no en la interfaz.

### Clases de salida (se eligen al empezar la run)

| Clase | Oxígeno | Integridad | Control | Cargas | Rasgo |
|---|---|---|---|---|---|
| **Buzo** | 8 | 5 | 6 | 4 | Balanceada. Default del tutorial |
| **Lastre** | 5 | 9 | 3 | 3 | Ignora el primer impacto de cada tramo |
| **Aguja** | 4 | 3 | 9 | 6 | Dash no consume carga bajo 600 m |
| **Carroñero** | 6 | 6 | 5 | 5 | +40% Chatarra, −20% Núcleos |

## Personajes secundarios

Cada uno tiene un arco de 4 escenas y desbloquea un sistema.

### 1. **Vey** — Mecánica del Ancla
- **Rol:** upgrades de tabla, voz del jugador cuando el jugador no la tiene
- **Actitud:** práctica, seca, sin ironía. Nunca pregunta cómo estás
- **Arco:** repara tablas de gente que no vuelve y las revende. Su arco es
  admitir que reconoce las tuyas
- **Desbloquea:** rama de upgrades avanzados (Quilla III+)
- **Visual:** brazos con injertos de metal Despierto — funcionales, no cool

### 2. **Idris Mor** — Contratista del Consorcio
- **Rol:** da las cuotas. Antagonista de sistema, no de combate
- **Actitud:** cordial, exacto, **nunca miente de forma verificable**
- **Arco:** de empleador a cómplice a testigo. Nunca se disculpa
- **Desbloquea:** contratos (misiones con modificadores de run)
- **Visual:** el único personaje que nunca se moja. Traje seco, impecable

### 3. **Halla** — Sin Lastre
- **Rol:** primera voz que dice que el Surge no es un recurso
- **Actitud:** calma total. No recluta, invita
- **Arco:** aparece a 800 m sin equipo de ascenso. Está bien. Eso es lo perturbador
- **Desbloquea:** ruta de Corrupción alta — habilidades que requieren Corrupción 50+
- **Visual:** sin casco. Los ojos ya no reflejan luz

### 4. **Ocho** — Otro Surfista
- **Rol:** compañero del tutorial. Muere al final del Acto I
- **Actitud:** ruidoso, imprudente, el único que se ríe
- **Arco:** post-mortem. Aparece como **Naufragio** en runs de otros jugadores.
  Su tabla es un ítem recuperable con su nombre
- **Desbloquea:** el sistema de Naufragios, diegéticamente
- **Visual:** tabla pintada a mano, la única con color no institucional

## Enemigos

### Ambientales (no persiguen)
| Nombre | Tramo | Comportamiento |
|---|---|---|
| **Velas** | 0–200 m | Medusas a la deriva. Daño por contacto, patrón fijo |
| **Columnas** | 200–600 m | Chorros térmicos verticales. Telegrafiados 0.8 s antes |
| **Mallas** | 600–1200 m | Redes de coral Despierto. Ralentizan y drenan Oxígeno |

### Despiertos (persiguen)
| Nombre | Tramo | Comportamiento |
|---|---|---|
| **Boya** | 400 m+ | Metal reanimado. Lento, imparable, bloquea rutas |
| **Grúa** | 800 m+ | Brazo de puerto. Ataca el eje de deriva del jugador |
| **Casco** | 1200 m+ | Un barco entero. Encuentro-arena, no esquivable |

**Regla de diseño:** ningún enemigo tiene ojos ni cara. El Surge anima
estructuras, no crea criaturas. La única cara en el abismo es la del jugador.

## Guía de arte (personajes)

- **Paleta:** cian → verde abisal → ámbar de emergencia. Rojo **solo** para daño
- **Silueta antes que detalle** — se juega en pantallas de 6", legibilidad primero
- **La luz siempre viene de abajo.** El Surge ilumina, la superficie no llega
- Especificaciones de export y tamaños: [Design/Characters/README.md](Design/Characters/README.md)

## Pendientes

- [ ] ¿El jugador tiene nombre o lo elige?
- [ ] Arcos de 4 escenas escritos para Vey, Idris, Halla
- [ ] Diseño de voz: ¿hay VO o todo texto?
- [ ] Set de emotes para el multijugador asíncrono
