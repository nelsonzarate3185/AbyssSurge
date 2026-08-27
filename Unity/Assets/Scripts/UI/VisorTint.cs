using UnityEngine;

namespace AbyssSurge.UI
{
    /// <summary>
    /// La franja del visor cambia de color según la Corrupción.
    /// Es el indicador de estado más importante del juego y vive en el
    /// personaje, no en la interfaz. Ver CHARACTER_DESIGN.md.
    /// </summary>
    public sealed class VisorTint : MonoBehaviour
    {
        [SerializeField] private SpriteRenderer visor;

        [Header("Gradiente de corrupción (0 → 100)")]
        [SerializeField] private Color clean = new(0.20f, 0.90f, 0.95f);   // cian
        [SerializeField] private Color touched = new(0.35f, 0.85f, 0.45f); // verde
        [SerializeField] private Color deep = new(0.95f, 0.70f, 0.20f);    // ámbar
        [SerializeField] private Color lost = Color.white;                 // blanco

        public void SetCorruption(int corruption)
        {
            var t = Mathf.Clamp01(corruption / 100f);

            visor.color = t switch
            {
                < 0.5f => Color.Lerp(clean, touched, t / 0.5f),
                < 0.75f => Color.Lerp(touched, deep, (t - 0.5f) / 0.25f),
                _ => Color.Lerp(deep, lost, (t - 0.75f) / 0.25f)
            };
        }
    }
}
