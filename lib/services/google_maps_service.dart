import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/secret_config.dart';

/// Utilidades para consumir la API de rutas de Google Maps y enviar ubicaciones.
class GoogleMapsService {
  GoogleMapsService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Obtiene la polilinea codificada entre dos puntos utilizando Google Directions API.
  Future<String?> getPolyline(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) async {
    final apiKey = SecretConfig.googleMapsApiKey;
    if (apiKey.isEmpty) {
      throw StateError(
        'Falta la API key de Google Maps. Configura la clave mediante SecretConfig '
        'o usando --dart-define=GOOGLE_MAPS_API_KEY=tu_api_key.',
      );
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$startLat,$startLon'
      '&destination=$endLat,$endLon'
      '&key=$apiKey',
    );

    int attempt = 0;
    const maxAttempts = 3;
    while (attempt < maxAttempts) {
      try {
        final response = await _httpClient
            .get(url)
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
          final routes = jsonResponse['routes'];
          if (routes is List && routes.isNotEmpty) {
            final firstRoute = routes.first as Map<String, dynamic>;
            final overview = firstRoute['overview_polyline'] as Map<String, dynamic>?;
            final polyline = overview?['points'] as String?;
            return polyline;
          }
          return null;
        } else {
          throw HttpException(
            'Google Directions API respondio con ${response.statusCode}',
          );
        }
      } on TimeoutException catch (_) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(Duration(seconds: 1 << attempt));
      } catch (_) {
        rethrow;
      }
    }
    return null;
  }

  /// Inicia el seguimiento en tiempo real del repartidor.
  ///
  /// Nota: La implementacion permanece simulada hasta que se integre con el
  /// paquete `location` dentro de la aplicacion que llame a este metodo.
  StreamSubscription<void>? startRealtimeTracking({
    required int idRepartidor,
    required Future<void> Function(int id, double lat, double lon) sendLocationToApi,
  }) {
    // Mantiene compatibilidad hacia atras sin abrir listeners cuando no se usa.
    return null;
  }
}

class HttpException implements Exception {
  HttpException(this.message);
  final String message;

  @override
  String toString() => 'HttpException: $message';
}
