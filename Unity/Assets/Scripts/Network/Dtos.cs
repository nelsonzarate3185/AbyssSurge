using System;

namespace AbyssSurge.Network
{
    /// <summary>
    /// DTOs del contrato cliente↔servidor. Los nombres de campo tienen que
    /// coincidir exactamente con lo que espera cada Edge Function
    /// (JsonUtility no soporta renombrado). Ver Docs/API/.
    /// </summary>
    [Serializable]
    public sealed class RunReport
    {
        public string seed;
        public string seedDate;   // null si no es la run diaria
        public string @class;     // diver | ballast | needle | scavenger
        public int depthMeters;
        public int coresCollected;
        public int scrapCollected;
        public int durationMs;
        public string outcome;    // ascended | drowned | crushed | abandoned
        public string startedAt;  // ISO-8601 UTC
    }

    [Serializable]
    public sealed class RunReceipt
    {
        public string runId;
        public bool credited;
        public int coresAwarded;
        public int scrapAwarded;
        public int corruptionGained;
        public bool wreckLeft;
    }

    [Serializable]
    public sealed class DailySeedResponse
    {
        public string date;
        public string seed;
    }

    [Serializable]
    public sealed class UpgradeResponse
    {
        public string slot;
        public int level;
    }

    [Serializable]
    public sealed class ClaimResponse
    {
        public int cores_awarded;
    }

    [Serializable]
    public sealed class ApiError
    {
        public string error;
    }
}
