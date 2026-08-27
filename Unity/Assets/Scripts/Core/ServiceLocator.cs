using System;
using System.Collections.Generic;

namespace AbyssSurge.Core
{
    /// <summary>
    /// Registro simple de servicios. Existe para evitar que aparezcan
    /// singletons nuevos por todo el proyecto y para que la lógica pura
    /// se pueda testear inyectando dobles.
    /// </summary>
    public static class ServiceLocator
    {
        private static readonly Dictionary<Type, object> Services = new();

        public static void Register<T>(T service) where T : class
        {
            if (service == null) throw new ArgumentNullException(nameof(service));
            Services[typeof(T)] = service;
        }

        public static T Get<T>() where T : class
        {
            if (Services.TryGetValue(typeof(T), out var service))
                return (T)service;

            throw new InvalidOperationException(
                $"Servicio no registrado: {typeof(T).Name}. " +
                "¿Falta registrarlo en GameBootstrap?");
        }

        public static bool TryGet<T>(out T service) where T : class
        {
            if (Services.TryGetValue(typeof(T), out var found))
            {
                service = (T)found;
                return true;
            }

            service = null;
            return false;
        }

        /// <summary>Usado por los tests entre casos.</summary>
        public static void Clear() => Services.Clear();
    }
}
