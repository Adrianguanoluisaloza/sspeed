// ✅ Import correcto para Flutter Web
import 'package:web/web.dart' as web;
import 'dart:ui_web'
    as ui; // Se importa con el alias 'ui' para acceder a platformViewRegistry

/// Registra una vista de plataforma para un IFrame de Google Maps.
///
/// Esta función es llamada por `live_map_screen.dart` para mostrar el mapa en la web.
void registerGoogleMapsIframe(String url) {
  final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
    ..src = url
    ..style.border = 'none'
    ..style.width = '100%'
    ..style.height = '100%';
  // Se usa ui.platformViewRegistry, que es la forma correcta en Flutter Web moderno.
  ui.platformViewRegistry.registerViewFactory(
    'google-maps-iframe',
    (int viewId) => iframe,
  );
}
