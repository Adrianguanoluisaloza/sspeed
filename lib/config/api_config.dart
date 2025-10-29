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
  // Aquí se podrían añadir otras configuraciones específicas del entorno,
  // como API keys, etc.

  const _ApiSettings({required this.baseUrl});

  // Método factory para obtener la URL base correcta en el entorno local
  // según la plataforma (Android, iOS, Web).
  factory _ApiSettings.local() {
    String localBaseUrl;
    if (kIsWeb) {
      // Usa la IP local para web, reemplaza por tu IP real si es necesario
      localBaseUrl = 'http://192.168.1.103:4567';
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      localBaseUrl = 'http://localhost:4567';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      localBaseUrl =
          'http://10.0.2.2:4567'; // IP especial para el emulador de Android
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      localBaseUrl =
          'http://localhost:4567'; // El simulador de iOS puede resolver localhost
    } else {
      localBaseUrl = 'http://localhost:4567'; // Fallback
    }
    return _ApiSettings(baseUrl: localBaseUrl);
  }

  // Configuración para el entorno de producción (AWS)
  static const _ApiSettings production = _ApiSettings(
    // TODO: Reemplazar con la URL real de AWS cuando la tengas
    baseUrl: 'https://tu-api-de-aws.com',
  );
}

// 3. Clase principal para gestionar la configuración de la API
class AppConfig {
  AppConfig._(); // Constructor privado

  // --- CONFIGURACIÓN PRINCIPAL ---
  // Cambia esta línea para apuntar a producción cuando despliegues la app.
  static const _currentEnvironment = Environment.local;
  // -----------------------------

  // Mapa que asocia cada entorno con su configuración
  static final Map<Environment, _ApiSettings> _settings = {
    Environment.local: _ApiSettings.local(),
    Environment.production: _ApiSettings.production,
  };

  static String? _manualOverride;

  /// Permite sobreescribir la URL base manualmente en tiempo de ejecución.
  /// Útil para pruebas con herramientas como Ngrok o para apuntar a una IP en la LAN.
  /// Pasa un string vacío o null para desactivar.
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
    return _settings[_currentEnvironment]!.baseUrl;
  }

  /// Ejemplo de cómo podrías tener una URL para un override manual (ej. Ngrok o IP de LAN)
  static const String lanExample = 'http://192.168.1.100:4567';
}
