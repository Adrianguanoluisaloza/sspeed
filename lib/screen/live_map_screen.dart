import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Importa la función para registrar el iframe de Google Maps solo en la plataforma web.
// El `ignore` es necesario porque el analizador no reconoce los imports condicionales.
// ignore: uri_does_not_exist
import '../utils/google_maps_iframe_web.dart'
    if (dart.library.html) '../utils/google_maps_iframe_web.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';

import '../models/pedido.dart';
import '../models/session_state.dart';
import '../services/database_service.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  static const LatLng _esmeraldasCenter = LatLng(0.988, -79.652);

  final Location _location = Location();
  GoogleMapController? _mapController;
  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _refreshTimer;

  LatLng? _userPosition;
  bool _isMapReady = false;
  String? _infoMessage;
  String? _errorMessage;
  PermissionStatus _permissionStatus = PermissionStatus.denied;

  Set<Marker> _markers = <Marker>{};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _locationSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await _checkAndRequestLocationPermission();
      await _refreshMarkers();
      if (mounted) {
        setState(() => _isMapReady = true);
        _refreshTimer ??= Timer.periodic(
            const Duration(seconds: 20), (_) => _refreshMarkers());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al inicializar: $e';
          _isMapReady = true;
        });
      }
    }
  }

  Future<void> _checkAndRequestLocationPermission() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            setState(() => _permissionStatus = PermissionStatus.denied);
          }
          return;
        }
      }

      _permissionStatus = await _location.hasPermission();
      if (_permissionStatus == PermissionStatus.denied) {
        _permissionStatus = await _location.requestPermission();
      }

      if (_permissionStatus != PermissionStatus.granted) {
        if (mounted) {
          setState(() {}); // Actualiza la UI para mostrar el estado del permiso
        }
        return;
      }

      // Si llegamos aquí, los permisos están concedidos.
      if (mounted) {
        setState(() => _permissionStatus = PermissionStatus.granted);
      }
      await _fetchCurrentUserLocation();
    } catch (e) {
      if (mounted) {
        setState(
            () => _errorMessage = 'Error con los permisos: ${e.toString()}');
      }
    }
  }

  Future<void> _fetchCurrentUserLocation() async {
    try {
      final currentLocation = await _location.getLocation();
      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        final latLng =
            LatLng(currentLocation.latitude!, currentLocation.longitude!);
        if (mounted) {
          setState(() {
            _userPosition = latLng;
            _infoMessage = 'Ubicación actualizada.';
          });
          _moveCamera(latLng, zoom: 15);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'No se pudo obtener tu ubicación.');
      }
    }
  }

  Future<void> _refreshMarkers() async {
    if (!mounted) return;
    final db = context.read<DatabaseService>();
    final session = context.read<SessionController>();
    final usuario = session.usuario;

    if (usuario == null || !usuario.isAuthenticated) {
      if (mounted) {
        setState(() {
          _infoMessage = 'Inicia sesión para ver tus pedidos en el mapa.';
          _markers.clear();
        });
      }
      return;
    }

    setState(() {
      _infoMessage = 'Actualizando...';
      _errorMessage = null;
    });

    try {
      // CORRECCIÓN: Lógica de obtención de pedidos simplificada.
      final List<Pedido> pedidos;
      switch (usuario.rol) {
        case 'repartidor':
          pedidos = await db.getPedidosPorDelivery(usuario.idUsuario);
          break;
        case 'admin':
        case 'soporte':
          pedidos = await db.getPedidosPorEstado('en camino');
          break;
        default: // 'cliente'
          final todosLosPedidos = await db.getPedidos(usuario.idUsuario);
          pedidos = todosLosPedidos
              .where((p) => p.estado != 'entregado' && p.estado != 'cancelado')
              .toList();
      }

      final markers = <Marker>{};
      if (_userPosition != null) {
        markers.add(Marker(
            markerId: const MarkerId('user'),
            position: _userPosition!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
            infoWindow: const InfoWindow(title: 'Estás aquí')));
      }

      final pedidosEnRuta = pedidos.where((p) => p.idDelivery != null).toList();
      if (pedidosEnRuta.isNotEmpty) {
        final futures = pedidosEnRuta.map((p) async {
          try {
            final loc = await db.getRepartidorLocation(p.idPedido);
            // Si la respuesta es null, no tiene tracking
            if (loc == null) return (p, null);

            // MEJORA: Se extraen las coordenadas de forma más segura y legible.
            // Esto maneja diferentes posibles nombres de clave que pueda devolver la API.
            final lat =
                _parseDouble(loc['latitud'] ?? loc['lat'] ?? loc['latitude']);
            final lon =
                _parseDouble(loc['longitud'] ?? loc['lng'] ?? loc['longitude']);

            // Si después de intentar con todas las claves, alguna es nula, no hay ubicación válida.
            if (lat == null || lon == null) return (p, null);

            // Se devuelve un registro (record) para mayor claridad en lugar de un mapa.
            return (p, {'lat': lat, 'lon': lon});
          } catch (e) {
            if (kDebugMode) {
              print(
                  'No se pudo obtener la ubicación para el pedido #${p.idPedido}: $e');
            }
            return (p, null);
          }
        });
        final results = await Future.wait(futures);

        for (final (pedido, ubicacion) in results) {
          if (ubicacion == null) continue;
          final lat = ubicacion['lat'];
          final lon = ubicacion['lon'];
          if (lat is double && lon is double) {
            markers.add(Marker(
                markerId: MarkerId(
                    'delivery_${pedido.idDelivery}_${pedido.idPedido}'),
                position: LatLng(lat, lon),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange),
                infoWindow: InfoWindow(
                    title: 'Repartidor #${pedido.idDelivery}',
                    snippet: 'Pedido ${pedido.idPedido}')));
          }
        }
      }

      if (mounted) {
        setState(() {
          _markers = markers;
          final deliveryCount =
              markers.length - (_userPosition != null ? 1 : 0);
          _infoMessage = deliveryCount == 0
              ? 'Sin repartidores activos.'
              : 'Mostrando $deliveryCount repartidores.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error al actualizar: ${e.toString()}');
      }
    }
  }

  void _moveCamera(LatLng target, {double zoom = 13}) =>
      _mapController?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: zoom)));
  double? _parseDouble(dynamic value) => (value is num)
      ? value.toDouble()
      : (value is String ? double.tryParse(value) : null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa en tiempo real')),
      body: _buildMapBody(),
      floatingActionButton: _buildMapControls(),
    );
  }

  // --- WIDGETS DE LA UI REDISEÑADA ---

  Widget _buildMapBody() {
    if (!_isMapReady) {
      return const Center(child: CircularProgressIndicator());
    }

    // Si los permisos no están concedidos, mostramos una vista de acción.
    if (_permissionStatus != PermissionStatus.granted) {
      return _buildPermissionDeniedView();
    }

    if (kIsWeb) {
      final lat = _userPosition?.latitude ?? _esmeraldasCenter.latitude;
      final lon = _userPosition?.longitude ?? _esmeraldasCenter.longitude;
      final url = 'https://maps.google.com/maps?q=$lat,$lon&z=15&output=embed';
      registerGoogleMapsIframe(url);
      return Stack(children: [
        SizedBox.expand(
          child: HtmlElementView(viewType: 'google-maps-iframe'),
        ),
        _buildTopInfoBar(),
      ]);
    } else {
      return Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
              target: _userPosition ?? _esmeraldasCenter,
              zoom: _userPosition != null ? 14 : 12),
          markers: _markers,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (controller) => _mapController = controller,
        ),
        _buildTopInfoBar(),
      ]);
    }
  }

  Widget _buildMapControls() {
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'center-map',
            onPressed: _userPosition != null
                ? () => _moveCamera(_userPosition!, zoom: 15)
                : null,
            backgroundColor: _userPosition != null
                ? Theme.of(context).primaryColor
                : Colors.grey,
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'refresh-map',
            onPressed: _refreshMarkers,
            backgroundColor: Theme.of(context).colorScheme.secondary,
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        ]);
  }

  Widget _buildPermissionDeniedView() {
    final isPermanentlyDenied =
        _permissionStatus == PermissionStatus.deniedForever;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_outlined,
                size: 96,
                color: Theme.of(context).colorScheme.primary.withAlpha(179)),
            const SizedBox(height: 24),
            Text(
              'Permiso de Ubicación Requerido',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isPermanentlyDenied
                  ? 'Para usar el mapa, debes habilitar los permisos de ubicación manualmente desde la configuración de tu dispositivo.'
                  : 'Necesitamos tu permiso para mostrar tu ubicación y los repartidores cercanos en el mapa.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: Icon(
                  isPermanentlyDenied ? Icons.settings : Icons.location_on),
              onPressed: () async {
                if (isPermanentlyDenied) {
                  await _location
                      .requestService(); // Intenta abrir la configuración
                } else {
                  _checkAndRequestLocationPermission();
                }
              },
              label: Text(isPermanentlyDenied
                  ? 'Abrir Configuración'
                  : 'Conceder Permiso'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopInfoBar() {
    final bool hasError = _errorMessage != null;
    final String message = _errorMessage ?? _infoMessage ?? 'Cargando mapa...';
    final Color bgColor = hasError
        ? Colors.red.shade400
        : Colors.black.withAlpha(153); // ~0.6 opacity
    final IconData icon =
        hasError ? Icons.warning_amber_rounded : Icons.info_outline_rounded;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
              .copyWith(top: MediaQuery.of(context).viewPadding.top + 8),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                Colors.black.withAlpha(128),
                Colors.transparent
              ])), // 0.5 opacity
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 5,
                      offset: Offset(0, 2))
                ]),
            child: Row(children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(message,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13))),
            ]),
          ),
        ),
      ),
    );
  }
}
