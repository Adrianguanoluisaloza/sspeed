import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Configuración centralizada para determinar la URL base de la API.
///
/// Se alinea con los entornos más comunes (web, emuladores y escritorio)
/// sin alterar la lógica previa, pero ofrece una detección automática del
/// host correcto para evitar errores de conexión en Android/iOS.
class AppConfig {
  AppConfig._();

  static const String _webAndDesktopBase = 'http://localhost:4567';
  static const String _androidEmulatorBase = 'http://10.0.2.2:4567';
  static const String _iosSimulatorBase = 'http://localhost:4567';

  static String? _manualOverride;

  /// Permite sobrescribir manualmente la URL base (por ejemplo, cuando se
  /// expone la API con Ngrok o una IP LAN). El valor se mantiene en memoria
  /// para la sesión actual de la aplicación.
  static void overrideBaseUrl(String baseUrl) {
    _manualOverride = baseUrl.trim().isEmpty ? null : baseUrl.trim();
  }

  /// Resuelve dinámicamente la URL base según la plataforma en ejecución.
  /// De esta forma Android utiliza `10.0.2.2` (emulador) mientras que web y
  /// escritorio permanecen en `localhost`.
  static String get baseUrl {
    if (_manualOverride != null) {
      return _manualOverride!;
    }
    if (kIsWeb) {
      return _webAndDesktopBase;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidEmulatorBase;
      case TargetPlatform.iOS:
        return _iosSimulatorBase;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return _webAndDesktopBase;
    }
  }

  /// Ayuda visual que recuerda la IP LAN típica al probar en dispositivos
  /// físicos; no se usa directamente para no interferir con la autodetección.
  static const String lanExample = 'http://192.168.1.100:4567';
}
