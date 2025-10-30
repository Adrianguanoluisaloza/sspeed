// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_util' as js_util;

import 'package:web/web.dart' as web;

class WebGeoPosition {
  final double lat;
  final double lng;
  final double? accuracy;
  final DateTime? timestamp;

  const WebGeoPosition(this.lat, this.lng, {this.accuracy, this.timestamp});
}

Future<WebGeoPosition?> getCurrentPosition({
  bool highAccuracy = true,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final geo =
      js_util.getProperty<web.Geolocation?>(web.window.navigator, 'geolocation');
  if (geo == null) {
    return null;
  }

  final completer = Completer<WebGeoPosition?>();

  final successCallback = (web.GeolocationPosition pos) {
    final coords = pos.coords;
    final latitude =
        js_util.getProperty<num?>(coords, 'latitude')?.toDouble();
    final longitude =
        js_util.getProperty<num?>(coords, 'longitude')?.toDouble();
    if (latitude == null || longitude == null) {
      completer.complete(null);
      return;
    }

    final accuracy =
        js_util.getProperty<num?>(coords, 'accuracy')?.toDouble();
    final timestampMs =
        js_util.getProperty<num?>(pos, 'timestamp')?.toDouble();

    completer.complete(
      WebGeoPosition(
        latitude,
        longitude,
        accuracy: accuracy,
        timestamp: timestampMs != null
            ? DateTime.fromMillisecondsSinceEpoch(timestampMs.round())
            : null,
      ),
    );
  }.toJS;

  final errorCallback = (web.GeolocationPositionError err) {
    completer.complete(null);
  }.toJS;

  geo.getCurrentPosition(
    successCallback,
    errorCallback,
    web.PositionOptions(
      enableHighAccuracy: highAccuracy,
      timeout: timeout.inMilliseconds,
    ),
  );

  return completer.future;
}

Stream<WebGeoPosition> watchPosition({
  bool highAccuracy = true,
}) {
  final controller = StreamController<WebGeoPosition>.broadcast();
  final geo =
      js_util.getProperty<web.Geolocation?>(web.window.navigator, 'geolocation');

  if (geo == null) {
    controller.close();
    return controller.stream;
  }

  int? watchId;

  final successCallback = (web.GeolocationPosition pos) {
    final coords = pos.coords;
    final latitude =
        js_util.getProperty<num?>(coords, 'latitude')?.toDouble();
    final longitude =
        js_util.getProperty<num?>(coords, 'longitude')?.toDouble();
    if (latitude == null || longitude == null) {
      controller.addError(
        StateError('Geolocation coordinates are not available.'),
      );
      return;
    }

    final accuracy =
        js_util.getProperty<num?>(coords, 'accuracy')?.toDouble();
    final timestampMs =
        js_util.getProperty<num?>(pos, 'timestamp')?.toDouble();

    controller.add(
      WebGeoPosition(
        latitude,
        longitude,
        accuracy: accuracy,
        timestamp: timestampMs != null
            ? DateTime.fromMillisecondsSinceEpoch(timestampMs.round())
            : null,
      ),
    );
  }.toJS;

  final errorCallback = (web.GeolocationPositionError err) {
    controller.addError(
      Exception('Geolocation error: ${err.message}'),
    );
  }.toJS;

  controller.onListen = () {
    watchId = geo.watchPosition(
      successCallback,
      errorCallback,
      web.PositionOptions(
        enableHighAccuracy: highAccuracy,
      ),
    );
  };

  controller.onCancel = () {
    final id = watchId;
    if (id != null) {
      geo.clearWatch(id);
    }
  };

  return controller.stream;
}
