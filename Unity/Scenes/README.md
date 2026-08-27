# Escenas

Las escenas `.unity` **no están en el repo todavía** — se crean desde el Editor.
Cuando existan, van acá y se agregan a *Build Settings* en este orden:

| # | Escena | Rol |
|---|---|---|
| 0 | `Boot.unity` | Arranque. `GameBootstrap` + auth. Fondo negro, sin UI |
| 1 | `Anchor.unity` | Base flotante: upgrades, cuotas, personajes |
| 2 | `Descent.unity` | La run. Generada proceduralmente desde la seed |
| 3 | `Debrief.unity` | Resultado: acreditación o naufragio |

## Reglas

- `Boot` es la escena 0 **siempre**. Nada más registra servicios.
- `Descent` no tiene contenido autoral: todo se genera desde
  `DeterministicRandom` con la seed que devuelve el servidor.
- Las escenas se editan de a una persona por vez, o se rompe el merge.
  Para trabajo paralelo usá prefabs y prefab variants.

## Convención de nombres dentro de la escena

```
--- SYSTEMS ---     objetos sin representación visual
--- WORLD ---       terreno, hazards, spawns
--- ACTORS ---      Surfista, Despiertos
--- UI ---          canvases
--- LIGHTING ---    la luz siempre viene de abajo
```
