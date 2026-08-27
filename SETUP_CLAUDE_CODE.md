# Trabajar en AbyssSurge con Claude Code

## Estructura mental del repo

Tres dominios que casi no se tocan entre sí:

1. **`Unity/`** — C#, cliente. No sabe nada de SQL.
2. **`Supabase/`** — SQL + TypeScript (Deno). No sabe nada de Unity.
3. **`Docs/` + `*.md` raíz** — el contrato entre los dos.

Si un cambio toca los tres, empezá por `Docs/API/` y actualizá el contrato primero.

## Comandos frecuentes

```bash
make help          # todos los targets
make db-start      # Supabase local (Docker)
make db-reset      # migrations + seeds desde cero
make db-diff       # genera migration a partir de cambios locales
make fn-serve      # Edge Functions en local
make fn-deploy     # deploy de funciones a producción
make check         # lint SQL + typecheck de funciones
```

## Convenciones que conviene respetar

### C# (Unity)
- Namespace por carpeta: `AbyssSurge.Core`, `AbyssSurge.Gameplay`, etc.
- Un tipo público por archivo, nombre de archivo = nombre del tipo
- `MonoBehaviour` solo donde hace falta ciclo de vida de Unity; la lógica pura
  va en clases planas y testeables
- Nada de `GameObject.Find` ni singletons nuevos — pasá referencias por
  inspector o por `ServiceLocator` (ver `Unity/Assets/Scripts/Core/`)

### SQL (Supabase)
- Migrations: `NNN_descripcion.sql`, numeración correlativa, **nunca se editan
  una vez aplicadas en remoto** — se agrega una nueva
- Toda tabla nueva arranca con `enable row level security` en la misma migration
- `snake_case` para tablas y columnas, plural para tablas (`runs`, `players`)

### Edge Functions
- Una carpeta por función, con `index.ts` adentro
- Validar input siempre — el cliente es hostil por definición
- Nunca devolver filas de otra tabla que no pasó por RLS

## Reglas de oro

- **El cliente nunca decide recompensas.** Toda acreditación de Núcleos,
  Corrupción o leaderboard pasa por una Edge Function que valida.
- **Los assets binarios grandes no van al repo.** `.psd`, `.wav`, `.fbx`, `.blend`
  están en `.gitignore`. Van a almacenamiento externo; en `Design/` queda el
  spec y el export final chico.
- **Los `.md` de diseño son la fuente de verdad.** Si el código contradice a
  `GAME_MECHANICS.md`, uno de los dos está mal — decidí cuál antes de seguir.

## Al pedirle cambios a Claude

Contexto útil para incluir en el prompt:

- Qué dominio tocás (`Unity/`, `Supabase/`, docs)
- Si el cambio afecta el contrato cliente↔servidor
- Números de balance: marcalos `[TUNE]` si son provisorios

Ejemplos que funcionan bien:

> "Agregá la tabla `wrecks` con RLS: un jugador solo lee naufragios de su
> misma seed diaria. Actualizá `Docs/API/` también."

> "En `Unity/Assets/Scripts/Gameplay/`, implementá el costo de ascenso según
> la fórmula de `GAME_MECHANICS.md` sección 4."

## Setup inicial de máquina

```bash
cp .env.example .env
npm i -g supabase            # o scoop install supabase
supabase login
supabase link --project-ref <tu-project-ref>
make db-start
```

Unity: abrí Unity Hub → Add project → seleccioná la carpeta `Unity/`.
