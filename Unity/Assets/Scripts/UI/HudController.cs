using AbyssSurge.Gameplay;
using UnityEngine;
using UnityEngine.UI;

namespace AbyssSurge.UI
{
    /// <summary>
    /// HUD de la run. Mantiene la interfaz al mínimo: el estado importante
    /// (corrupción) se comunica por el color del visor del personaje,
    /// no por la UI. Ver CHARACTER_DESIGN.md.
    /// </summary>
    public sealed class HudController : MonoBehaviour
    {
        [SerializeField] private SurgerController surger;

        [Header("Widgets")]
        [SerializeField] private Image oxygenBar;
        [SerializeField] private Image integrityBar;
        [SerializeField] private Text depthLabel;
        [SerializeField] private Text coresLabel;
        [SerializeField] private CanvasGroup ascentWarning;

        [Header("Colores")]
        [SerializeField] private Color oxygenSafe = new(0.20f, 0.85f, 0.90f);
        [SerializeField] private Color oxygenCritical = new(0.95f, 0.55f, 0.10f);

        private void LateUpdate()
        {
            var run = surger != null ? surger.Session : null;
            if (run == null) return;

            var oxygenRatio = Mathf.Clamp01(run.Oxygen / 100f);
            oxygenBar.fillAmount = oxygenRatio;
            oxygenBar.color = Color.Lerp(oxygenCritical, oxygenSafe, oxygenRatio);

            integrityBar.fillAmount = Mathf.Clamp01(run.Integrity / 100f);

            depthLabel.text = $"{Mathf.FloorToInt(run.DepthMeters)} m";
            coresLabel.text = run.Cores.ToString();

            // El aviso más importante del juego: ya no alcanza para subir.
            var alpha = run.AscentUnaffordable ? PulsingAlpha() : 0f;
            ascentWarning.alpha = Mathf.MoveTowards(ascentWarning.alpha, alpha, Time.deltaTime * 3f);
        }

        private static float PulsingAlpha() => 0.55f + Mathf.PingPong(Time.time * 0.9f, 0.45f);
    }
}
