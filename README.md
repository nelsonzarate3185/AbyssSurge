# Abyss Surge — *Rise from the Darkness*

RPG estratégico mobile (Clash of Clans + Solo Leveling) en Unity, con backend
en Supabase y pagos por MercadoPago Paraguay. Android + iOS.

> ### ⚠️ Estado del repo
>
> La fuente de verdad del diseño es
> [Docs/Abyss_Surge_Trama_y_Personajes.pdf](Docs/Abyss_Surge_Trama_y_Personajes.pdf).
>
> [STORY.md](STORY.md) y [CHARACTER_DESIGN.md](CHARACTER_DESIGN.md) están
> reescritos desde ese PDF y son válidos.
>
> El backend de [Supabase/](Supabase/) y el contrato de
> [Docs/API/](Docs/API/) están reescritos sobre la premisa correcta:
> cazadores, mazmorras, clanes, rangos y gemas. **Todavía sin ejecutar** —
> ver "Estado real" en [Supabase/README.md](Supabase/README.md).
>
> **Siguen desactualizados:** [GAME_MECHANICS.md](GAME_MECHANICS.md) (tiene un
> índice de los sistemas reales arriba, pero el cuerpo describe otro juego),
> los scripts de [Unity/](Unity/) y [Docs/Architecture/](Docs/Architecture/).

## Estructura del workspace

| Carpeta | Qué contiene |
|---|---|
| [Docs/Abyss_Surge_Trama_y_Personajes.pdf](Docs/Abyss_Surge_Trama_y_Personajes.pdf) | **Fuente de verdad** del diseño |
| [STORY.md](STORY.md) | Trama, mundo de Aetheron, 6 actos ✅ |
| [GAME_MECHANICS.md](GAME_MECHANICS.md) | Índice de sistemas reales + borrador descartado ⚠️ |
| [CHARACTER_DESIGN.md](CHARACTER_DESIGN.md) | 4 clases jugables, 4 NPCs, rangos, poderes ✅ |
| [SETUP_CLAUDE_CODE.md](SETUP_CLAUDE_CODE.md) | Cómo trabajar en este repo con Claude Code |
| [Unity/](Unity/) | Cliente móvil — scripts, escenas, recursos ⚠️ |
| [Supabase/](Supabase/) | Schema SQL, Edge Functions, seeds ✅ |
| [Docs/](Docs/) | Documentación técnica (API, arquitectura) |
| [Design/](Design/) | Especificaciones y assets visuales |

## Arranque rápido

```bash
make env                   # crea .env desde .env.example
make help                  # lista de comandos disponibles
make db-link               # vincula con el proyecto AbyssSurge en Supabase
make db-start              # levanta Supabase local (requiere Docker)
make db-reset              # aplica migrations + seeds
```

Proyecto Supabase: **AbyssSurge** · ref `ocmroiupftpbsukuqvyu`

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
