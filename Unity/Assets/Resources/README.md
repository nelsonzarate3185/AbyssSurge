# Resources

Assets cargados en runtime con `Resources.Load`. Usar con moderación: todo lo
que está acá entra al build **siempre**, esté referenciado o no.

```
Resources/
├── Prefabs/      # Surfista, hazards, Despiertos, pickups
├── Sprites/      # Atlas 2D. Ver ../../Design/ para los specs
├── Animations/   # Controllers y clips
└── Audio/        # Solo .ogg comprimido — los .wav están en .gitignore
```

## Reglas

- **Prefiere referencias directas por inspector.** `Resources` solo para lo que
  se instancia dinámicamente desde código y no se puede referenciar.
- Sprites: atlas por tramo de profundidad, no uno global. Ver
  [Design/README.md](../../../Design/README.md) para tamaños y pivotes.
- Audio: `.ogg` a 44.1 kHz. Los `.wav` fuente viven fuera del repo.
- Nada de assets de más de 2 MB acá adentro sin discutirlo — infla el APK.
