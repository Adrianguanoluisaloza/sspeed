import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

class AppConfig {
  AppConfig._();

  // Bases por plataforma (local)
  static const String _webAndDesktopBase = 'http://localhost:4567';
  static const String _androidEmulatorBase = 'http://10.0.2.2:4567';
  static const String _iosSimulatorBase = 'http://localhost:4567';

  // 👉 NEON PostgREST (tu endpoint)
  static const String _neonRestBase =
      'https://ep-quiet-thunder-ady30ys2-pooler.c-2.us-east-1.aws.neon.tech:5432/neondb?sslmode=require';

  static String? _manualOverride;

  /// Activa la base de Neon para todo el runtime
  static void useNeonRest() {
    _manualOverride = _neonRestBase;
  }

  /// Override manual (Ngrok / LAN / Prod)
  static void overrideBaseUrl(String baseUrl) {
    _manualOverride = baseUrl.trim().isEmpty ? null : baseUrl.trim();
  }

  /// Resuelve la URL base
  static String get baseUrl {
    if (_manualOverride != null) return _manualOverride!;
    if (kIsWeb) return _webAndDesktopBase;

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

  static const String lanExample = 'http://192.168.1.100:4567';
}
