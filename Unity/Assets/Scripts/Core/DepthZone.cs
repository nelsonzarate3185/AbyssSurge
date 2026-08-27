namespace AbyssSurge.Core
{
    public enum DepthTier
    {
        Platform,     // 0–200 m
        Thermocline,  // 200–600 m
        DeadZone,     // 600–1200 m
        Rift          // 1200 m+
    }

    /// <summary>
    /// Tabla de tramos de GAME_MECHANICS.md §3. Lógica pura, sin Unity.
    /// </summary>
    public readonly struct DepthZone
    {
        public readonly DepthTier Tier;
        public readonly float Pressure;
        public readonly float LootMultiplier;

        private DepthZone(DepthTier tier, float pressure, float loot)
        {
            Tier = tier;
            Pressure = pressure;
            LootMultiplier = loot;
        }

        public static DepthZone ForDepth(float meters)
        {
            if (meters < 200f) return new DepthZone(DepthTier.Platform, 1.0f, 1.0f);
            if (meters < 600f) return new DepthZone(DepthTier.Thermocline, 1.4f, 1.8f);
            if (meters < 1200f) return new DepthZone(DepthTier.DeadZone, 2.1f, 3.2f);
            return new DepthZone(DepthTier.Rift, 3.0f, 5.0f);
        }
    }
}
