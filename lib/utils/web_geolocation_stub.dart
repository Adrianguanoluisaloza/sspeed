// Fallback (non-web) implementation: returns null/no stream.

class WebGeoPosition {
  final double lat;
  final double lng;
  WebGeoPosition(this.lat, this.lng);
}

Future<WebGeoPosition?> getCurrentPosition() async {
  return null;
}

Stream<WebGeoPosition> watchPosition() async* {}

