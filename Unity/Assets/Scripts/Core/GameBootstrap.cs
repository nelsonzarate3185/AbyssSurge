using AbyssSurge.Network;
using UnityEngine;

namespace AbyssSurge.Core
{
    /// <summary>
    /// Único punto de arranque. Registra servicios y sobrevive a los cambios
    /// de escena. Debe estar en la escena `Boot`.
    /// </summary>
    [DefaultExecutionOrder(-1000)]
    public sealed class GameBootstrap : MonoBehaviour
    {
        [Header("Configuración")]
        [SerializeField] private GameConfig config;

        [Header("Supabase")]
        [Tooltip("SUPABASE_URL. En builds de release se inyecta desde CI, no se commitea.")]
        [SerializeField] private string supabaseUrl = "http://127.0.0.1:54321";

        [Tooltip("SUPABASE_ANON_KEY. Es pública por diseño — RLS es lo que protege.")]
        [SerializeField] private string supabaseAnonKey = "";

        private void Awake()
        {
            if (config == null)
            {
                Debug.LogError("[Bootstrap] Falta asignar GameConfig.", this);
                enabled = false;
                return;
            }

            DontDestroyOnLoad(gameObject);

            ServiceLocator.Register(config);
            ServiceLocator.Register(new AbyssApi(supabaseUrl, supabaseAnonKey));

            Application.targetFrameRate = 60;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;

            Debug.Log("[Bootstrap] Servicios registrados.");
        }
    }
}
