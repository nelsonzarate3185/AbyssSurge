# UI

## Principio

**El HUD es mínimo.** El estado más importante del juego —la Corrupción— se
comunica por el color del visor del personaje, no por la interfaz.
Ver [VisorTint.cs](../../Unity/Assets/Scripts/UI/VisorTint.cs).

## Elementos del HUD de run

| Elemento | Posición | Notas |
|---|---|---|
| Barra de Oxígeno | Borde izquierdo, vertical | Interpola cian → ámbar según nivel |
| Barra de Integridad | Borde derecho, vertical | Rojo solo al recibir daño |
| Profundidad | Superior centro | Números grandes, sin decimales |
| Núcleos | Superior derecha | Contador simple |
| Aviso de ascenso | Overlay pulsante | Aparece cuando `Oxígeno < CostoDeAscenso` |

El **aviso de ascenso** es el momento más importante de la run: es cuando el
jugador se entera de que ya no puede volver. Tiene que ser imposible de ignorar
sin bloquear la jugabilidad.

## Pantallas de base (Ancla)

- Upgrades de tabla (4 slots × 10 niveles)
- Cuota semanal del Consorcio
- Diálogo de personajes
- Leaderboard diario
- Mapa de naufragios disponibles

## Specs

- Diseñar a **1080×1920** (9:16), safe area de 48 dp en todos los bordes
- Target táctil mínimo: **44×44 dp**
- Iconos: SVG fuente → export PNG @1x / @2x / @3x
- Sin texto embebido en imágenes (hay que localizar)

## Pendientes

- [ ] Elegir tipografía — legible a 6", con acentos y ñ
- [ ] Estados de foco/press para todos los targets
- [ ] Modo de alto contraste
- [ ] Layout para pantallas ultra-anchas (20:9)
