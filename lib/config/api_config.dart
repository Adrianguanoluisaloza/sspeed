import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

// 1. Define los entornos de la aplicación
enum Environment {
  development,
  production,
}

// 2. Clase para la configuración de la API específica de cada entorno
class ApiSettings {
  final String baseUrl;

  const ApiSettings({required this.baseUrl});

  // Configuración para el entorno de DESARROLLO (localhost, emuladores O NGROK)
  factory ApiSettings.forDevelopment() {
    // === ¡IMPORTANTE! ===
    // REEMPLAZA ESTA URL CON TU URL ACTUAL DE NGROK CADA VEZ QUE LA INICIES.
    // O déjala en blanco para usar la lógica de localhost/10.0.2.2.
    const String ngrokUrl = 'https://https://martyrly-transnatural-sonya.ngrok-free.dev'; // <--- ¡TU URL DE NGROK AQUÍ!
    //https://https://martyrly-transnatural-sonya.ngrok-free.dev
    if (ngrokUrl.isNotEmpty) {
      // Si se proporciona una URL de Ngrok, úsala directamente.
      return ApiSettings(baseUrl: ngrokUrl);
    }

    // Lógica por defecto para desarrollo local (si ngrokUrl está vacía)
    String devBaseUrl;
    if (kIsWeb) {
      devBaseUrl = 'http://localhost:4567';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      devBaseUrl = 'http://10.0.2.2:4567';
    } else {
      devBaseUrl = 'http://localhost:4567';
    }
    return ApiSettings(baseUrl: devBaseUrl);
  }

  // Configuración para el entorno de PRODUCCIÓN (tu dominio real)
  static const ApiSettings production = ApiSettings(
    baseUrl: 'https://api.tu-dominio-produccion.com', // ¡REEMPLAZA CON TU URL REAL DE PRODUCCIÓN!
  );
}

// 3. Clase principal para gestionar la configuración de la API
class AppConfig {
  AppConfig._(); // Constructor privado para evitar instanciación

  // --- CONFIGURACIÓN PRINCIPAL ---
  static const String _envString =
  String.fromEnvironment('APP_ENV', defaultValue: 'development');

  static const String _compileTimeBaseUrl =
  String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static final Environment _currentEnvironment =
  _envString.toLowerCase() == 'production'
      ? Environment.production
      : Environment.development;

  // -----------------------------

  static final Map<Environment, ApiSettings> _settings = {
    Environment.development: ApiSettings.forDevelopment(), // Usará la Ngrok URL si está definida
    Environment.production: ApiSettings.production,
  };

  static String? _runtimeOverrideBaseUrl;

  /// Permite sobrescribir la URL base manualmente en tiempo de ejecución.
  static void overrideBaseUrl(String? baseUrl) {
    _runtimeOverrideBaseUrl =
    (baseUrl != null && baseUrl.trim().isNotEmpty) ? baseUrl.trim() : null;
  }

  /// Devuelve la URL base que la aplicación debe usar.
  /// La prioridad es:
  /// 1. Override manual en tiempo de ejecución (`AppConfig.overrideBaseUrl()`)
  /// 2. Variable de entorno de compilación (`--dart-define=API_BASE_URL`)
  /// 3. Configuración predefinida del entorno (`ApiSettings.forDevelopment()` o `ApiSettings.production`)
  static String get baseUrl {
    if (_runtimeOverrideBaseUrl != null) {
      return _runtimeOverrideBaseUrl!;
    }
    if (_compileTimeBaseUrl.isNotEmpty) {
      return _compileTimeBaseUrl;
    }
    return _settings[_currentEnvironment]!.baseUrl;
  }
}