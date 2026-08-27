using System;
using System.Collections;
using System.Text;
using UnityEngine;
using UnityEngine.Networking;

namespace AbyssSurge.Network
{
    /// <summary>
    /// Cliente REST mínimo contra Supabase. No usa el SDK oficial para
    /// mantener el build de Android liviano.
    ///
    /// Regla: el cliente nunca escribe en `runs`. Solo llama Edge Functions
    /// y las tres RPCs permitidas. Ver Docs/API/.
    /// </summary>
    public sealed class AbyssApi
    {
        private readonly string _baseUrl;
        private readonly string _anonKey;

        public string AccessToken { get; set; }

        public AbyssApi(string baseUrl, string anonKey)
        {
            _baseUrl = baseUrl.TrimEnd('/');
            _anonKey = anonKey;
        }

        public IEnumerator SubmitRun(RunReport report,
                                     Action<RunReceipt> onSuccess,
                                     Action<string> onError)
            => PostJson("/functions/v1/submit-run", JsonUtility.ToJson(report), onSuccess, onError);

        public IEnumerator FetchDailySeed(Action<DailySeedResponse> onSuccess,
                                          Action<string> onError)
            => PostJson("/functions/v1/daily-seed", "{}", onSuccess, onError);

        public IEnumerator PurchaseUpgrade(string slot,
                                           Action<UpgradeResponse> onSuccess,
                                           Action<string> onError)
            => PostJson("/rest/v1/rpc/purchase_upgrade",
                        $"{{\"p_slot\":\"{slot}\"}}", onSuccess, onError);

        public IEnumerator ClaimWreck(string wreckId,
                                      Action<ClaimResponse> onSuccess,
                                      Action<string> onError)
            => PostJson("/rest/v1/rpc/claim_wreck",
                        $"{{\"p_wreck_id\":\"{wreckId}\"}}", onSuccess, onError);

        private IEnumerator PostJson<T>(string path, string body,
                                        Action<T> onSuccess, Action<string> onError)
        {
            using var request = new UnityWebRequest($"{_baseUrl}{path}", UnityWebRequest.kHttpVerbPOST)
            {
                uploadHandler = new UploadHandlerRaw(Encoding.UTF8.GetBytes(body)),
                downloadHandler = new DownloadHandlerBuffer(),
                timeout = 15
            };

            request.SetRequestHeader("Content-Type", "application/json");
            request.SetRequestHeader("apikey", _anonKey);
            if (!string.IsNullOrEmpty(AccessToken))
                request.SetRequestHeader("Authorization", $"Bearer {AccessToken}");

            yield return request.SendWebRequest();

            if (request.result != UnityWebRequest.Result.Success)
            {
                onError?.Invoke(string.IsNullOrEmpty(request.downloadHandler.text)
                    ? request.error
                    : request.downloadHandler.text);
                yield break;
            }

            T parsed;
            try
            {
                parsed = JsonUtility.FromJson<T>(request.downloadHandler.text);
            }
            catch (Exception e)
            {
                onError?.Invoke($"respuesta inesperada: {e.Message}");
                yield break;
            }

            onSuccess?.Invoke(parsed);
        }
    }
}
