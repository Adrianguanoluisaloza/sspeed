import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';

import '../config/secret_config.dart';
import '../models/pedido.dart';
import '../models/session_state.dart';
import '../services/database_service.dart';
import '../utils/maps_script_loader.dart';

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
      if (kIsWeb) {
        final key = SecretConfig.googleMapsApiKey;
        if (key.isEmpty) {
          setState(() => _errorMessage = 'Configura GOOGLE_MAPS_API_KEY.');
          return;
        }
        await ensureGoogleMapsScriptLoaded(key);
      }

      await _loadUserLocation();
      await _refreshMarkers();
      if (mounted) {
        setState(() => _isMapReady = true);
        _refreshTimer ??= Timer.periodic(const Duration(seconds: 20), (_) => _refreshMarkers());
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

  Future<void> _loadUserLocation() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          setState(() => _infoMessage = 'Activa la ubicación para ver el mapa.');
          return;
        }
      }

      PermissionStatus permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
        if (permission != PermissionStatus.granted) {
          setState(() => _infoMessage = 'Se requieren permisos de ubicación.');
          return;
        }
      }

      final currentLocation = await _location.getLocation();
      if (currentLocation.latitude != null && currentLocation.longitude != null) {
        final latLng = LatLng(currentLocation.latitude!, currentLocation.longitude!);
        if (mounted) {
          setState(() => _userPosition = latLng);
          _moveCamera(latLng, zoom: 15);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _infoMessage = 'No se pudo obtener tu ubicación.');
    }
  }

  Future<void> _refreshMarkers() async {
    if (!mounted) return;
    final db = context.read<DatabaseService>();
    final session = context.read<SessionController>();
    final usuario = session.usuario;

    if (usuario == null) {
      setState(() {
        _infoMessage = 'Inicia sesión para ver tus pedidos en el mapa.';
        _markers.clear();
      });
      return;
    }

    setState(() {
      _infoMessage = 'Actualizando...';
      _errorMessage = null;
    });

    try {
      List<Pedido> pedidos = [];
      if (usuario.isAuthenticated) {
        switch (usuario.rol) {
          case 'delivery':
            pedidos = await db.getPedidosPorDelivery(usuario.idUsuario);
            break;
          case 'admin':
          case 'soporte':
            pedidos = await db.getPedidosPorEstado('en camino');
            break;
          default:
            pedidos = (await db.getPedidos(usuario.idUsuario))
                .where((p) => p.estado != 'entregado' && p.estado != 'cancelado')
                .toList();
        }
      }

      final markers = <Marker>{};
      if (_userPosition != null) {
        markers.add(Marker(markerId: const MarkerId('user'), position: _userPosition!, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), infoWindow: const InfoWindow(title: 'Estás aquí')));
      }

      final pedidosEnRuta = pedidos.where((p) => p.idDelivery != null).toList();
      if (pedidosEnRuta.isNotEmpty) {
        final futures = pedidosEnRuta.map((p) async {
          try {
            final loc = await db.getRepartidorLocation(p.idPedido);
            return (p, loc);
          } catch (e) {
            // Ignora errores de tracking para un solo pedido
            if (kDebugMode) {
              print('No se pudo obtener la ubicación para el pedido #${p.idPedido}: $e');
            }
            return (p, null);
          }
        });
        final results = await Future.wait(futures);

        for (final (pedido, ubicacion) in results) {
          if (ubicacion == null) continue;
          final lat = _parseDouble(ubicacion['latitud'] ?? ubicacion['lat']);
          final lon = _parseDouble(ubicacion['longitud'] ?? ubicacion['lng']);
          if (lat == null || lon == null) continue;

          markers.add(Marker(markerId: MarkerId('delivery_${pedido.idDelivery}_${pedido.idPedido}'), position: LatLng(lat, lon), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange), infoWindow: InfoWindow(title: 'Repartidor #${pedido.idDelivery}', snippet: 'Pedido ${pedido.idPedido}')));
        }
      }

      if (mounted) {
        setState(() {
          _markers = markers;
          final deliveryCount = markers.length - (_userPosition != null ? 1 : 0);
          _infoMessage = deliveryCount == 0 ? 'Sin repartidores activos.' : 'Mostrando $deliveryCount repartidores.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error al actualizar: ${e.toString()}');
      }
    }
  }

  void _moveCamera(LatLng target, {double zoom = 13}) => _mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: zoom)));
  double? _parseDouble(dynamic value) => (value is num) ? value.toDouble() : (value is String ? double.tryParse(value) : null);

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
    return Stack(children: [
      GoogleMap(
        initialCameraPosition: CameraPosition(target: _userPosition ?? _esmeraldasCenter, zoom: _userPosition != null ? 14 : 12),
        markers: _markers,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        onMapCreated: (controller) => _mapController = controller,
      ),
      _buildTopInfoBar(),
    ]);
  }

  Widget _buildMapControls() {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      FloatingActionButton(heroTag: 'center-map', onPressed: () => _moveCamera(_userPosition ?? _esmeraldasCenter, zoom: _userPosition != null ? 15 : 12), child: const Icon(Icons.my_location)),
      const SizedBox(height: 12),
      FloatingActionButton(heroTag: 'refresh-map', onPressed: _refreshMarkers, child: const Icon(Icons.refresh)),
    ]);
  }

  Widget _buildTopInfoBar() {
    final bool hasError = _errorMessage != null;
    final String message = _errorMessage ?? _infoMessage ?? 'Cargando mapa...';
    final Color bgColor = hasError ? Colors.red.shade400 : Colors.black.withAlpha(153); // ~0.6 opacity
    final IconData icon = hasError ? Icons.warning_amber_rounded : Icons.info_outline_rounded;

    return Positioned(
      top: 0, left: 0, right: 0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8).copyWith(top: MediaQuery.of(context).viewPadding.top + 8),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withAlpha(128), Colors.transparent])), // 0.5 opacity
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))]),
            child: Row(children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
            ]),
          ),
        ),
      ),
    );
  }
}
