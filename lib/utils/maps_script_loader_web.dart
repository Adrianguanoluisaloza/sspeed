// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'package:web/helpers.dart';
import 'package:web/web.dart' as web;
import 'dart:js_util' as js_util;

Completer<void>? _loader;

Future<void> ensureGoogleMapsScriptLoaded(String apiKey) {
  if (isGoogleMapsScriptLoaded) {
    return Future.value();
  }

  if (_loader != null) {
    return _loader!.future;
  }

  _loader = Completer<void>();

  final existing = web.document.getElementById('google-maps-script');
  if (existing != null) {
    if (isGoogleMapsScriptLoaded) {
      _completeLoader();
    } else {
      existing.onLoad.first.then((_) => _completeLoader());
      existing.onError.first.then(
        (_) => _completeLoader(
            error: StateError('No se pudo cargar Google Maps JS.')),
      );
    }
    return _loader!.future;
  }

  final script = web.document.createElement('script') as web.HTMLScriptElement
    ..id = 'google-maps-script'
    ..type = 'text/javascript'
    ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey'
    ..async = true
    ..defer = true;

  script.onLoad.listen((_) => _completeLoader());
  script.onError.listen(
    (_) =>
        _completeLoader(error: StateError('No se pudo cargar Google Maps JS.')),
  );

  web.document.head?.appendChild(script);

  return _loader!.future;
}

void _completeLoader({Object? error}) {
  if (_loader == null || _loader!.isCompleted) return;
  if (error != null) {
    _loader!.completeError(error);
  } else {
    _loader!.complete();
  }
  _loader = null;
}

bool get isGoogleMapsScriptLoaded {
  if (!js_util.hasProperty(web.window, 'google')) {
    return false;
  }
  final google = js_util.getProperty(web.window, 'google');
  if (google.isUndefinedOrNull) return false;
  return js_util.hasProperty(google, 'maps');
}
