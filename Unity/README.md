# Unity — Cliente móvil de AbyssSurge

Proyecto Unity **2022.3 LTS** (URP 2D), target Android / iOS.

## Abrir el proyecto

Unity Hub → **Add project from disk** → seleccioná esta carpeta (`Unity/`),
no la raíz del repo.

## Arquitectura

```
Assets/Scripts/
├── Core/        # Servicios, configuración, lógica sin dependencias de escena
├── Gameplay/    # Simulación de la run, control del Surfista, hazards
├── UI/          # HUD y presentación. Solo lee estado, nunca lo muta
└── Network/     # Cliente REST contra Supabase (Edge Functions + RPCs)
```

### Regla de dependencias

```
UI ──▶ Gameplay ──▶ Core ◀── Network
```

`Core` no conoce a nadie. `Network` no conoce `Gameplay`. `UI` nunca escribe
en el estado de la run: lo lee y lo dibuja.

### Piezas principales

| Archivo | Rol |
|---|---|
| `Core/GameBootstrap.cs` | Único punto de arranque. Registra servicios. Va en la escena `Boot` |
| `Core/GameConfig.cs` | ScriptableObject con todos los números de balance |
| `Core/DeterministicRandom.cs` | PRNG sembrado con la seed del servidor. **No tocar sin coordinar con `_shared/seed.ts`** |
| `Core/DepthZone.cs` | Tabla de tramos y presión (GAME_MECHANICS.md §3) |
| `Gameplay/RunSession.cs` | Estado y reglas de la run. **C# puro, testeable sin escena** |
| `Gameplay/SurgerController.cs` | Input táctil → simulación |
| `Network/AbyssApi.cs` | REST contra Supabase con `UnityWebRequest` |
| `UI/HudController.cs` | Oxígeno, integridad, profundidad, aviso de ascenso |
| `UI/VisorTint.cs` | Color del visor según Corrupción |

## Escenas

| Escena | Rol |
|---|---|
| `Boot` | Arranque, registro de servicios, auth. Nunca se ve |
| `Anchor` | Base: upgrades, cuotas, narrativa |
| `Descent` | La run |
| `Debrief` | Resultado, acreditación, naufragio |

Las escenas van en [Scenes/](Scenes/) — ver el README de esa carpeta.

## Convenciones

- Namespace = carpeta: `AbyssSurge.Core`, `AbyssSurge.Gameplay`, …
- Un tipo público por archivo; nombre de archivo = nombre del tipo
- Nada de `GameObject.Find` ni singletons nuevos → usá `ServiceLocator`
- Los `MonoBehaviour` son cáscaras finas; la lógica va en clases planas
- Números de balance **siempre** en `GameConfig`, nunca hardcodeados

## Reglas que no se rompen

- **El cliente no acredita nada.** `RunSession` calcula localmente para
  mostrar feedback inmediato, pero la verdad es la respuesta de `submit-run`.
- **`DeterministicRandom` y `_shared/seed.ts` son un mismo algoritmo en dos
  lenguajes.** Si cambia uno, cambia el otro o la seed diaria se rompe.
- `SUPABASE_ANON_KEY` es pública por diseño — lo que protege es RLS.
  La `service_role` key **nunca** entra al cliente.

## Pendientes

- [ ] Migrar de `Input.GetTouch` al nuevo Input System
- [ ] Tests EditMode para `RunSession` (oxígeno, costo de ascenso, corrupción)
- [ ] Object pooling para hazards
- [ ] Auth anónima de Supabase en `Boot`
- [ ] Assembly definitions por carpeta para acelerar compilación
