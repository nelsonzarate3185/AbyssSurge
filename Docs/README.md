# Documentación técnica

## Orden de lectura sugerido

### Si venís a entender el juego
1. [../README.md](../README.md) — qué es esto
2. [../STORY.md](../STORY.md) — trama
3. [../GAME_MECHANICS.md](../GAME_MECHANICS.md) — sistemas
4. [../CHARACTER_DESIGN.md](../CHARACTER_DESIGN.md) — personajes

### Si venís a escribir código
1. [../SETUP_CLAUDE_CODE.md](../SETUP_CLAUDE_CODE.md) — cómo se trabaja acá
2. [Architecture/](Architecture/) — cómo encajan las piezas
3. [API/](API/) — el contrato cliente ↔ servidor
4. [../Unity/README.md](../Unity/README.md) o [../Supabase/README.md](../Supabase/README.md)

### Si venís a hacer arte
1. [../CHARACTER_DESIGN.md](../CHARACTER_DESIGN.md) — guía de arte
2. [../Design/README.md](../Design/README.md) — especificaciones de export

## Qué documento manda

Cuando dos fuentes se contradicen, este es el orden de autoridad:

1. **`Supabase/migrations/`** — el schema es la realidad
2. **`Docs/API/`** — el contrato entre cliente y servidor
3. **`GAME_MECHANICS.md`** — la intención de diseño
4. El código

Si el código contradice a `GAME_MECHANICS.md`, **uno de los dos está mal**.
Decidí cuál antes de seguir; no dejes la contradicción viva.

## Contenido

| Carpeta | Qué hay |
|---|---|
| [API/](API/) | Endpoints, payloads, códigos de error, reglas de validación |
| [Architecture/](Architecture/) | Vista general, flujo de una run, decisiones y sus porqués |
