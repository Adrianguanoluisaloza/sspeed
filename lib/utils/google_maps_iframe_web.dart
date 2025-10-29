// Archivo solo para web: registro de iframe para Google Maps
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui' as ui;
import 'dart:html' as html;

void registerGoogleMapsIframe(String url) {
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(
    'google-maps-iframe',
    (int viewId) => html.IFrameElement()
      ..src = url
      ..style.border = '0'
      ..width = '100%'
      ..height = '100%'
  );
}
