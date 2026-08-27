# AbyssSurge

Juego móvil (Unity) con backend en la nube (Supabase).

> **Estado:** scaffold inicial. Los documentos de diseño son un borrador v0 —
> están pensados para que los edites, no para tomarlos como canon.

## Estructura del workspace

| Carpeta | Qué contiene |
|---|---|
| [STORY.md](STORY.md) | Trama, worldbuilding, arcos narrativos |
| [GAME_MECHANICS.md](GAME_MECHANICS.md) | Sistemas de juego, economía, progresión |
| [CHARACTER_DESIGN.md](CHARACTER_DESIGN.md) | Personajes, roles, stats base |
| [SETUP_CLAUDE_CODE.md](SETUP_CLAUDE_CODE.md) | Cómo trabajar en este repo con Claude Code |
| [Unity/](Unity/) | Cliente móvil — scripts, escenas, recursos |
| [Supabase/](Supabase/) | Schema SQL, Edge Functions, seeds |
| [Docs/](Docs/) | Documentación técnica (API, arquitectura) |
| [Design/](Design/) | Especificaciones y assets visuales |

## Arranque rápido

```bash
cp .env.example .env       # completá las claves de Supabase
make help                  # lista de comandos disponibles
make db-start              # levanta Supabase local (requiere Docker)
make db-reset              # aplica migrations + seeds
```

Abrí `AbyssSurge.code-workspace` en VS Code para tener las carpetas separadas.

El cliente Unity se abre desde Unity Hub apuntando a la carpeta `Unity/`.

## Requisitos

- **Unity** 2022.3 LTS o superior (módulos Android / iOS)
- **Supabase CLI** — `npm i -g supabase` o `scoop install supabase`
- **Docker Desktop** (para Supabase local)
- **Node.js** 20+ (para las Edge Functions y Deno tooling)

## Convenciones

- Namespace C#: `AbyssSurge.<Area>` (`Core`, `UI`, `Gameplay`, `Network`)
- Tablas SQL en `snake_case`, siempre con RLS activo
- Migrations con nombre `NNN_descripcion.sql`, nunca se editan una vez aplicadas
- Los assets grandes (`.psd`, `.wav`, `.fbx`) no van al repo — ver [.gitignore](.gitignore)
