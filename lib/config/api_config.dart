import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

// 1. Define los entornos de la aplicaciÃ³n
enum Environment {
  local,
  production,
}

// 2. Define la configuraciÃ³n para cada entorno
class _ApiSettings {
  final String baseUrl;

  const _ApiSettings({required this.baseUrl});

  // MÃ©todo factory para obtener la URL base correcta en el entorno local
  factory _ApiSettings.local() {
    // CORRECCIÃ“N: Se simplifica la lÃ³gica de detecciÃ³n de plataforma.
    String localBaseUrl;
    if (kIsWeb) {
      // Para web, localhost funciona si la API tiene CORS configurado.
      // Si no, se puede usar la IP de la LAN: 'http://192.168.1.100:4567'
      localBaseUrl = 'http://localhost:4567';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // 10.0.2.2 es la direcciÃ³n especial que usa el emulador de Android
      // para apuntar al localhost de la mÃ¡quina anfitriona.
      localBaseUrl = 'http://10.0.2.2:4567';
    } else {
      // Para todas las demÃ¡s plataformas (Windows, macOS, Linux, iOS), 
      // 'localhost' se resuelve correctamente.
      localBaseUrl = 'http://localhost:4567';
    }
    return _ApiSettings(baseUrl: localBaseUrl);
  }

  // ConfiguraciÃ³n para el entorno de producciÃ³n
  static const _ApiSettings production = _ApiSettings(
    // TODO: Reemplazar con la URL real del servidor de producciÃ³n
    baseUrl: 'https://tu-api-de-produccion.com',
  );
}

// 3. Clase principal para gestionar la configuraciÃ³n de la API
class AppConfig {
  AppConfig._(); // Constructor privado

  // --- CONFIGURACIÃ“N PRINCIPAL ---
  static const _currentEnvironment = Environment.local;
  // -----------------------------

  static final Map<Environment, _ApiSettings> _settings = {
    Environment.local: _ApiSettings.local(),
    Environment.production: _ApiSettings.production,
  };

  static String? _manualOverride;

  /// Permite sobreescribir la URL base manualmente en tiempo de ejecuciÃ³n.
  /// Ãštil para pruebas con herramientas como Ngrok o para apuntar a una IP en la LAN.
  ///
  /// Ejemplo de uso en main.dart:
  /// `AppConfig.overrideBaseUrl('https://tu-dominio.ngrok-free.app');`
  ///
  /// Pasa un string vacÃ­o o null para desactivar el override.
  static void overrideBaseUrl(String? baseUrl) {
    _manualOverride =
        (baseUrl != null && baseUrl.trim().isNotEmpty) ? baseUrl.trim() : null;
  }

  /// Devuelve la URL base que la aplicaciÃ³n debe usar.
  /// Da prioridad al override manual, si existe.
  static String get baseUrl {
    if (_manualOverride != null) {
      return _manualOverride!;
    }
    return _settings[_currentEnvironment]!.baseUrl;
  }
}
