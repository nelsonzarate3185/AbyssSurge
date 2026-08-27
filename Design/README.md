# Design — Assets visuales

Especificaciones y exports. Los archivos fuente (`.psd`, `.ai`, `.blend`) **no
van al repo** — están en `.gitignore`. Acá viven las specs y los exports
finales livianos.

## Principios (de CHARACTER_DESIGN.md)

1. **La luz siempre viene de abajo.** El Surge ilumina; la superficie no llega.
2. **Silueta antes que detalle.** Se juega en pantallas de 6".
3. **Rojo solo para daño.** Nunca decorativo.
4. **Nada tiene cara** salvo el jugador. El Surge anima estructuras, no crea
   criaturas.

## Paleta

| Rol | Hex | Uso |
|---|---|---|
| Cian abisal | `#33E5F2` | Surge limpio, corrupción 0, HUD seguro |
| Verde profundo | `#59D973` | Corrupción media, vegetación Despierta |
| Ámbar de emergencia | `#F2B333` | Corrupción alta, alertas |
| Blanco umbral | `#FFFFFF` | Corrupción 100 |
| Rojo daño | `#E5484D` | **Solo** impacto y pérdida de integridad |
| Azul lastre | `#0A1826` | Fondo, silueta de terreno |

## Especificaciones de export

| Tipo | Formato | Tamaño | Notas |
|---|---|---|---|
| Sprites de personaje | PNG, RGBA | 256×256 base | Pivote en el centro de masa |
| Hazards | PNG, RGBA | 128×128 | Silueta legible al 50% |
| Fondos de tramo | PNG | 1080×1920 | Parallax en 3 capas |
| Iconos de UI | SVG → PNG @1x/@2x/@3x | 48 dp base | Sin texto embebido |
| Atlas | Uno por tramo de profundidad | máx. 2048² | Nunca un atlas global |

Los sprites entran a Unity en [Unity/Assets/Resources/Sprites/](../Unity/Assets/Resources/Sprites/).

## Estructura

```
Design/
├── Characters/     # Surfista, Vey, Idris, Halla, Ocho, enemigos
├── UI/             # HUD, menús, iconos, tipografía
└── Environments/   # Los 4 tramos de profundidad
```

## Pendientes

- [ ] Definir tipografía (necesita legibilidad a 6" y soporte de acentos)
- [ ] Turnarounds del Surfista con los 4 estados de visor
- [ ] Guía de animación: frames por acción, timing
- [ ] Dónde viven los archivos fuente (¿Drive, Git LFS, Supabase Storage?)
