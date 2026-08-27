using System;

namespace AbyssSurge.Core
{
    /// <summary>
    /// PRNG determinista (xorshift128) sembrado con la seed hexadecimal que
    /// devuelve la Edge Function <c>daily-seed</c>.
    ///
    /// IMPORTANTE: si cambia este algoritmo, la seed diaria deja de generar
    /// el mismo nivel para todos los jugadores. Ver GAME_MECHANICS.md §8.
    /// </summary>
    public sealed class DeterministicRandom
    {
        private uint _x, _y, _z, _w;

        public DeterministicRandom(string hexSeed)
        {
            if (string.IsNullOrEmpty(hexSeed) || hexSeed.Length < 8)
                throw new ArgumentException("Seed inválida", nameof(hexSeed));

            // Se toman 4 bloques de 8 hex chars; si la seed es más corta se cicla.
            _x = Block(hexSeed, 0);
            _y = Block(hexSeed, 1);
            _z = Block(hexSeed, 2);
            _w = Block(hexSeed, 3);

            // Estado todo-cero rompe xorshift.
            if ((_x | _y | _z | _w) == 0) _x = 0x9E3779B9;
        }

        private static uint Block(string hex, int index)
        {
            var start = (index * 8) % hex.Length;
            var span = new char[8];
            for (var i = 0; i < 8; i++) span[i] = hex[(start + i) % hex.Length];
            return Convert.ToUInt32(new string(span), 16);
        }

        public uint NextUInt()
        {
            var t = _x ^ (_x << 11);
            _x = _y; _y = _z; _z = _w;
            _w = _w ^ (_w >> 19) ^ t ^ (t >> 8);
            return _w;
        }

        /// <summary>Float en [0, 1).</summary>
        public float NextFloat() => (NextUInt() >> 8) / (float)(1 << 24);

        /// <summary>Entero en [min, max).</summary>
        public int Range(int min, int max)
        {
            if (max <= min) return min;
            return min + (int)(NextUInt() % (uint)(max - min));
        }

        public float Range(float min, float max) => min + NextFloat() * (max - min);
    }
}
