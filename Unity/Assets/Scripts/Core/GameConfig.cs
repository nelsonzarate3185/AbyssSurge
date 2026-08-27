using UnityEngine;

namespace AbyssSurge.Core
{
    /// <summary>
    /// Constantes de balance. Los valores viven en un asset para poder
    /// tunearlos sin recompilar. Fuente de verdad: GAME_MECHANICS.md.
    /// </summary>
    [CreateAssetMenu(menuName = "AbyssSurge/Game Config", fileName = "GameConfig")]
    public sealed class GameConfig : ScriptableObject
    {
        [Header("Descenso")]
        [Tooltip("Velocidad de caída libre, m/s.")]
        public float FreeFallSpeed = 34f;

        [Tooltip("Velocidad con frenado máximo, m/s.")]
        public float BrakedSpeed = 11f;

        [Tooltip("Aceleración lateral por unidad de inclinación.")]
        public float LateralAcceleration = 18f;

        [Header("Oxígeno")]
        public float OxygenMax = 100f;

        [Tooltip("Consumo base por segundo, a presión 1.0.")]
        public float OxygenDrainPerSecond = 1.6f;

        [Tooltip("Multiplicador de consumo mientras se frena.")]
        public float BrakeOxygenMultiplier = 2.1f;

        [Header("Ascenso")]
        [Tooltip("Oxígeno requerido por metro de profundidad. GAME_MECHANICS.md §4.")]
        public float AscentOxygenPerMeter = 0.4f;

        [Header("Surge")]
        public int SurgeChargesMax = 4;
        public float DashImpulse = 26f;

        [Header("Corrupción")]
        [Tooltip("Profundidad a partir de la cual se gana corrupción.")]
        public float CorruptionThresholdMeters = 600f;

        [Tooltip("Metros por punto de corrupción, pasado el umbral.")]
        public float MetersPerCorruptionPoint = 300f;
    }
}
