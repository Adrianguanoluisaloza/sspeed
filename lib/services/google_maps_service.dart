import 'dart:async';
import 'dart:convert'; // Se añade para poder decodificar la respuesta JSON
import 'package:http/http.dart' as http;

// NOTA: Para que esto funcione, necesitarás añadir los siguientes paquetes a tu pubspec.yaml:
//   google_maps_flutter: ^2.0.0 (o la versión más reciente)
//   location: ^5.0.0 (o la versión más reciente)

class GoogleMapsService {
  // ¡IMPORTANTE! Reemplaza esto con tu propia API Key de Google Maps.
  static const String _apiKey = 'AQUI_VA_TU_API_KEY_DE_GOOGLE_MAPS';

  final http.Client _httpClient;

  GoogleMapsService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  /// Obtiene la polilínea codificada para dibujar una ruta entre dos puntos.
  Future<String?> getPolyline(
    double startLat, double startLon,
    double endLat, double endLon,
  ) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=$startLat,$startLon&destination=$endLat,$endLon&key=$_apiKey');

    int attempt = 0;
    const maxAttempts = 3;
    while (attempt < maxAttempts) {
      try {
        final response = await _httpClient.get(url).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          // CORRECCIÓN: Se decodifica el JSON y se extrae la polilínea real.
          final jsonResponse = json.decode(response.body);
          if (jsonResponse['routes'] != null && (jsonResponse['routes'] as List).isNotEmpty) {
            final polyline = jsonResponse['routes'][0]['overview_polyline']['points'];
            return polyline;
          } else {
            print('La respuesta de Google no contiene rutas.');
            return null;
          }
        } else {
          print('Error con la API de Google: ${response.statusCode}');
          return null;
        }
      } catch (e) {
        print('Intento #$attempt fallido para obtener la ruta: $e');
        attempt++;
        if (attempt >= maxAttempts) {
          print("Se alcanzó el máximo de reintentos.");
          return null;
        }
        await Future.delayed(Duration(seconds: 1 << attempt));
      }
    }
    return null;
  }

  /// Inicia el seguimiento de la ubicación del repartidor y la envía al backend.
  StreamSubscription<void>? startRealtimeTracking({
    required int idRepartidor,
    required Future<void> Function(int id, double lat, double lon) sendLocationToApi,
  }) {
    print("Función de seguimiento iniciada (simulación).");
    // NOTA: Para que esto funcione de verdad, necesitarás descomentar y configurar
    // el paquete 'location'.
    /*
    final location = Location();
    return location.onLocationChanged.listen((LocationData currentLocation) {
      final lat = currentLocation.latitude;
      final lon = currentLocation.longitude;
      if (lat != null && lon != null) {
         print("Nueva ubicación: $lat, $lon");
         sendLocationToApi(idRepartidor, lat, lon);
       }
    });
    */
    return null;
  }
}
