# Characters

## Prioridad de producción

| # | Asset | Estado | Notas |
|---|---|---|---|
| 1 | Surfista — turnaround | ⬜ Pendiente | 4 variantes de visor (corrupción 0/50/75/100) |
| 2 | Surfista — set de animación | ⬜ Pendiente | Caída, frenado, dash, impacto, ascenso |
| 3 | Hazards ambientales | ⬜ Pendiente | Velas, Columnas, Mallas |
| 4 | Despiertos | ⬜ Pendiente | Boya, Grúa, Casco |
| 5 | Vey | ⬜ Pendiente | Retrato de base, 3 expresiones |
| 6 | Idris Mor | ⬜ Pendiente | Retrato de base, 3 expresiones |
| 7 | Halla | ⬜ Pendiente | Retrato + aparición in-run a 800 m |
| 8 | Ocho | ⬜ Pendiente | Retrato + tabla como ítem de naufragio |

## Specs

- Sprites de gameplay: **256×256** PNG RGBA, pivote en el centro de masa
- Retratos de base: **512×768** PNG RGBA
- Enemigos: **128×128**, silueta legible reducida al 50%

## Recordatorios de diseño

- El visor del Surfista es una **franja única de luz**, no dos ojos.
  Su color es el HUD de Corrupción — ver [VisorTint.cs](../../Unity/Assets/Scripts/UI/VisorTint.cs)
- Los Despiertos son **estructuras portuarias reanimadas**: grúas, boyas,
  cascos. Nunca criaturas. Nunca ojos.
- Halla es el único personaje **sin casco**. Sus ojos no reflejan luz.
- La tabla de Ocho es el único objeto con color no institucional del juego.

Referencia completa: [CHARACTER_DESIGN.md](../../CHARACTER_DESIGN.md)
