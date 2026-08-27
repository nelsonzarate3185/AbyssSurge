using AbyssSurge.Core;
using UnityEngine;

namespace AbyssSurge.Gameplay
{
    /// <summary>
    /// Traduce el input táctil (un dedo) al estado de la run.
    /// Control: arrastrar = inclinar, mantener = frenar, doble tap = dash.
    /// Ver GAME_MECHANICS.md §1.
    /// </summary>
    [RequireComponent(typeof(Rigidbody2D))]
    public sealed class SurgerController : MonoBehaviour
    {
        [SerializeField] private GameConfig config;
        [SerializeField] private float doubleTapWindow = 0.28f;
        [SerializeField] private float brakeHoldThreshold = 0.15f;

        private Rigidbody2D _body;
        private RunSession _session;
        private float _lastTapTime = float.NegativeInfinity;
        private float _holdStartedAt;
        private bool _isHolding;
        private float _tiltInput;

        public RunSession Session => _session;

        private void Awake() => _body = GetComponent<Rigidbody2D>();

        public void Begin(RunSession session) => _session = session;

        private void Update()
        {
            if (_session == null || _session.Outcome != RunOutcome.InProgress) return;

            ReadInput();
            _session.Tick(Time.deltaTime, IsBraking);
        }

        private bool IsBraking =>
            _isHolding && Time.time - _holdStartedAt >= brakeHoldThreshold;

        private void FixedUpdate()
        {
            if (_session == null || _session.Outcome != RunOutcome.InProgress) return;

            var verticalSpeed = IsBraking ? config.BrakedSpeed : config.FreeFallSpeed;
            var lateral = _tiltInput * config.LateralAcceleration;

            _body.velocity = new Vector2(
                lateral,
                _session.IsAscending ? verticalSpeed : -verticalSpeed);
        }

        private void ReadInput()
        {
            if (Input.touchCount == 0)
            {
                if (_isHolding) EndHold();
                _tiltInput = Mathf.MoveTowards(_tiltInput, 0f, Time.deltaTime * 4f);
                return;
            }

            var touch = Input.GetTouch(0);

            switch (touch.phase)
            {
                case TouchPhase.Began:
                    BeginHold();
                    break;

                case TouchPhase.Moved:
                case TouchPhase.Stationary:
                    // Inclinación normalizada por el ancho de pantalla.
                    _tiltInput = Mathf.Clamp(
                        (touch.position.x / Screen.width - 0.5f) * 2f, -1f, 1f);
                    break;

                case TouchPhase.Ended:
                case TouchPhase.Canceled:
                    EndHold();
                    break;
            }
        }

        private void BeginHold()
        {
            if (Time.time - _lastTapTime <= doubleTapWindow)
            {
                _session.TryDash();
                _lastTapTime = float.NegativeInfinity;
                return;
            }

            _isHolding = true;
            _holdStartedAt = Time.time;
        }

        private void EndHold()
        {
            // Un hold corto cuenta como tap; encadenar dos dispara el dash.
            if (_isHolding && Time.time - _holdStartedAt < brakeHoldThreshold)
                _lastTapTime = Time.time;

            _isHolding = false;
        }

        private void OnCollisionEnter2D(Collision2D collision)
        {
            if (_session == null) return;

            if (collision.gameObject.TryGetComponent<IHazard>(out var hazard))
                _session.TakeDamage(hazard.Damage);
        }
    }

    public interface IHazard
    {
        float Damage { get; }
    }
}
