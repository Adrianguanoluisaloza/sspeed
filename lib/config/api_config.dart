import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

// 1. Define los entornos de la aplicación
enum Environment {
  local,
  production,
}

// 2. Define la configuración para cada entorno
class _ApiSettings {
  final String baseUrl;

  const _ApiSettings({required this.baseUrl});

  // Método factory para obtener la URL base correcta en el entorno local
  factory _ApiSettings.local() {
    // CORRECCIÓN: Se simplifica la lógica de detección de plataforma.
    String localBaseUrl;
    if (kIsWeb) {
      // Para web, localhost funciona si la API tiene CORS configurado.
      // Si no, se puede usar la IP de la LAN: 'http://192.168.1.100:4567'
      localBaseUrl = 'http://localhost:4567';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // 10.0.2.2 es la dirección especial que usa el emulador de Android
      // para apuntar al localhost de la máquina anfitriona.
      localBaseUrl = 'http://10.0.2.2:4567';
    } else {
      // Para todas las demÃ¡s plataformas (Windows, macOS, Linux, iOS),
      // 'localhost' se resuelve correctamente.
      localBaseUrl = 'http://localhost:4567';
    }
    return _ApiSettings(baseUrl: localBaseUrl);
  }

  // Configuración para el entorno de producción
  static const _ApiSettings production = _ApiSettings(
    // TODO: Reemplazar con la URL real del servidor de producción.
    // ¡IMPORTANTE! No subas URLs o claves reales a repositorios públicos. Usa variables de entorno.
    baseUrl: 'https://api.tu-dominio.com',
  );
}

// 3. Clase principal para gestionar la configuración de la API
class AppConfig {
  AppConfig._(); // Constructor privado

  // --- CONFIGURACIÓN PRINCIPAL ---
  // MEJORA: Se lee el entorno desde las variables de compilación de Flutter.
  // Para compilar en producción, usa: flutter build --dart-define=APP_ENV=production
  static const String _env =
      String.fromEnvironment('APP_ENV', defaultValue: 'local');
  static const String _envBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static final Environment _currentEnvironment =
      _env.toLowerCase() == 'production'
          ? Environment.production
          : Environment.local;
  // -----------------------------

  static final Map<Environment, _ApiSettings> _settings = {
    Environment.local: _ApiSettings.local(),
    Environment.production: _ApiSettings.production,
  };

  static String? _manualOverride;

  /// Permite sobreescribir la URL base manualmente en tiempo de ejecución.
  /// Útil para pruebas con herramientas como Ngrok o para apuntar a una IP en la LAN.
  ///
  /// Ejemplo de uso en main.dart:
  /// `AppConfig.overrideBaseUrl('https://tu-dominio.ngrok-free.app');`
  ///
  /// Pasa un string vacío o null para desactivar el override.
  static void overrideBaseUrl(String? baseUrl) {
    _manualOverride =
        (baseUrl != null && baseUrl.trim().isNotEmpty) ? baseUrl.trim() : null;
  }

  /// Devuelve la URL base que la aplicación debe usar.
  /// Da prioridad al override manual, si existe.
  static String get baseUrl {
    if (_manualOverride != null) {
      return _manualOverride!;
    }
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }
    return _settings[_currentEnvironment]!.baseUrl;
  }
}
