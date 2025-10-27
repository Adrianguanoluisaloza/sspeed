class SecretConfig {
  SecretConfig._();

  /// API key for Google Gemini.
  static const String geminiApiKey =
  String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'AIzaSyAApL9LGM4PI6yQEaYYkzuhZjfG2zC3zy0');

  /// API key for Google Maps SDK.
  static const String googleMapsApiKey =
  String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: 'AIzaSyAIvLI8lMrPF4gNnMiBW2Pd52ZAgnV6BTw');

  static bool get hasGeminiKey => geminiApiKey.isNotEmpty;
  static bool get hasMapsKey => googleMapsApiKey.isNotEmpty;
}
