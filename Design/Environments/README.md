# Environments

Cuatro tramos de profundidad. Cada uno tiene que ser reconocible **por
silueta y color en menos de un segundo** — el jugador está cayendo.

| Tramo | Profundidad | Paleta | Lectura visual |
|---|---|---|---|
| **Plataforma** | 0–200 m | Azul lastre + luz de superficie | Estructuras humanas intactas. Se ve el sol arriba |
| **Termoclina** | 200–600 m | Verde profundo, partículas suspendidas | Última luz natural. Aparecen los chorros térmicos |
| **Zona muerta** | 600–1200 m | Negro + solo Surge cian | Sin luz ambiental. Solo se ve lo que el Surge ilumina |
| **La Grieta** | 1200 m+ | Ámbar sobre negro | La luz viene de abajo y es cálida. Está mal que sea cálida |

## Specs

- Fondos: **1080×1920** PNG, parallax en 3 capas
- Un atlas por tramo, máximo 2048×2048. **Nunca un atlas global**
- Terreno tileable verticalmente — el descenso es infinito por generación

## Regla de iluminación

La luz **siempre** viene de abajo. En Plataforma hay una segunda fuente desde
arriba (el sol) que se va apagando; a partir de Termoclina desaparece y no
vuelve. Esa pérdida es narrativa, no técnica.

## Pendientes

- [ ] Reglas de generación procedural por tramo (densidad, ancho de canal)
- [ ] Transiciones entre tramos: ¿corte o degradado?
- [ ] Props ambientales de la Grieta — todavía no hay concepto
