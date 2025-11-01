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
  final String geminiApiKey;

  const ApiSettings({required this.baseUrl, required this.geminiApiKey});

  // Configuración para el entorno de DESARROLLO (localhost, emuladores O NGROK)
  factory ApiSettings.forDevelopment() {
    // === ¡MUY IMPORTANTE! ===
    // REEMPLAZA ESTA URL CON TU URL ACTUAL DE NGROK CADA VEZ QUE LA INICIES.
    // O déjala en blanco para usar la lógica de localhost/10.0.2.2.
    const String ngrokUrl =
        'https://feyly-electrotropic-obdulia.ngrok-free.dev ';

    // === ¡CLAVE DE GEMINI PARA PRUEBAS! ===
    // PEGA AQUÍ TU CLAVE DE LA API DE GEMINI.
    const String geminiKeyForTesting = 'PEGA-AQUI-TU-CLAVE-DE-GEMINI';

    String finalBaseUrl;
    if (ngrokUrl.isNotEmpty && ngrokUrl != 'PEGA-AQUÍ-TU-NUEVA-URL-DE-NGROK') {
      finalBaseUrl = ngrokUrl;
    } else {
      if (kIsWeb) {
        finalBaseUrl = 'http://localhost:7070';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        finalBaseUrl = 'http://10.0.2.2:7070';
      } else {
        finalBaseUrl = 'http://localhost:7070';
      }
    }
    return ApiSettings(
        baseUrl: finalBaseUrl, geminiApiKey: geminiKeyForTesting);
  }

  // Configuración para el entorno de PRODUCCIÓN (tu dominio real)
  static const ApiSettings production = ApiSettings(
    baseUrl:
        'https://api.tu-dominio-produccion.com', // ¡REEMPLAZA CON TU URL REAL DE PRODUCCIÓN!
    geminiApiKey: 'CLAVE_DE_PRODUCCION_NO_DEBE_ESTAR_AQUI',
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
    Environment.development:
        ApiSettings.forDevelopment(), // Usará la Ngrok URL si está definida
    Environment.production: ApiSettings.production,
  };

  static String? _runtimeOverrideBaseUrl;

  /// Permite sobrescribir la URL base manualmente en tiempo de ejecución.
  static void overrideBaseUrl(String? baseUrl) {
    _runtimeOverrideBaseUrl =
        (baseUrl != null && baseUrl.trim().isNotEmpty) ? baseUrl.trim() : null;
  }

  /// Devuelve la URL base que la aplicación debe usar.
  static String get baseUrl {
    if (_runtimeOverrideBaseUrl != null) {
      return _runtimeOverrideBaseUrl!;
    }
    if (_compileTimeBaseUrl.isNotEmpty) {
      return _compileTimeBaseUrl;
    }
    return _settings[_currentEnvironment]!.baseUrl;
  }

  /// Devuelve la clave de API de Gemini para el entorno actual.
  static String get geminiApiKey {
    return _settings[_currentEnvironment]!.geminiApiKey;
  }
}
