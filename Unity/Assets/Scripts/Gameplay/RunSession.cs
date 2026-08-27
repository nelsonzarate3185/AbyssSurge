using System;
using AbyssSurge.Core;

namespace AbyssSurge.Gameplay
{
    public enum RunOutcome { InProgress, Ascended, Drowned, Crushed, Abandoned }

    /// <summary>
    /// Estado y reglas de una run. Lógica pura, sin dependencias de Unity:
    /// se puede testear en EditMode sin escena.
    /// </summary>
    public sealed class RunSession
    {
        private readonly GameConfig _config;

        public RunSession(GameConfig config, string seed, string surgerClass)
        {
            _config = config ?? throw new ArgumentNullException(nameof(config));
            Seed = seed;
            SurgerClass = surgerClass;
            Oxygen = config.OxygenMax;
            SurgeCharges = config.SurgeChargesMax;
            StartedAtUtc = DateTime.UtcNow;
        }

        public string Seed { get; }
        public string SurgerClass { get; }
        public DateTime StartedAtUtc { get; }

        public float DepthMeters { get; private set; }
        public float Oxygen { get; private set; }
        public float Integrity { get; private set; } = 100f;
        public int SurgeCharges { get; private set; }
        public int Cores { get; private set; }
        public int Scrap { get; private set; }
        public bool IsAscending { get; private set; }
        public RunOutcome Outcome { get; private set; } = RunOutcome.InProgress;

        public DepthZone Zone => DepthZone.ForDepth(DepthMeters);

        /// <summary>Oxígeno necesario para volver desde la profundidad actual.</summary>
        public float AscentCost => DepthMeters * _config.AscentOxygenPerMeter;

        /// <summary>True cuando ya no alcanza el oxígeno para subir. El punto sin retorno.</summary>
        public bool AscentUnaffordable => Oxygen < AscentCost;

        public void Tick(float deltaSeconds, bool braking)
        {
            if (Outcome != RunOutcome.InProgress) return;

            var pressure = Zone.Pressure;
            var drain = _config.OxygenDrainPerSecond * pressure;
            if (braking) drain *= _config.BrakeOxygenMultiplier;

            Oxygen = Math.Max(0f, Oxygen - drain * deltaSeconds);

            var speed = braking ? _config.BrakedSpeed : _config.FreeFallSpeed;
            DepthMeters = Math.Max(0f, DepthMeters + (IsAscending ? -speed : speed) * deltaSeconds);
            if (DepthMeters > DeepestMeters) DeepestMeters = DepthMeters;

            if (IsAscending && DepthMeters <= 0f)
            {
                Outcome = RunOutcome.Ascended;
                return;
            }

            if (Oxygen <= 0f) Outcome = RunOutcome.Drowned;
        }

        public void BeginAscent() => IsAscending = true;

        public bool TryDash()
        {
            if (SurgeCharges <= 0 || Outcome != RunOutcome.InProgress) return false;
            SurgeCharges--;
            DepthMeters = Math.Max(0f, DepthMeters + _config.DashImpulse * (IsAscending ? -1f : 1f));
            if (DepthMeters > DeepestMeters) DeepestMeters = DepthMeters;
            return true;
        }

        public void TakeDamage(float amount)
        {
            if (Outcome != RunOutcome.InProgress) return;

            Integrity = Math.Max(0f, Integrity - amount * Zone.Pressure);
            if (Integrity <= 0f) Outcome = RunOutcome.Crushed;
        }

        public void Collect(int cores, int scrap)
        {
            Cores += cores;
            Scrap += scrap;
        }

        public void Abandon() => Outcome = RunOutcome.Abandoned;

        /// <summary>
        /// Corrupción ganada. Debe coincidir con <c>corruptionGain()</c> de la
        /// Edge Function <c>submit-run</c> — el servidor recalcula y manda.
        /// </summary>
        public int CorruptionGain()
        {
            if (DeepestMeters <= _config.CorruptionThresholdMeters) return 0;
            return (int)((DeepestMeters - _config.CorruptionThresholdMeters)
                         / _config.MetersPerCorruptionPoint);
        }

        /// <summary>Máxima profundidad alcanzada — lo que se reporta al servidor.</summary>
        public float DeepestMeters { get; private set; }
    }
}
