import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
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
  bool _isLoading = true;
  String? _error;

  Set<Marker> _markers = <Marker>{};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      if (kIsWeb) {
        final key = SecretConfig.googleMapsApiKey;
        if (key.isEmpty) {
          setState(() {
            _error = 'Configura GOOGLE_MAPS_API_KEY para visualizar el mapa.';
            _isLoading = false;
          });
          return;
        }
        await ensureGoogleMapsScriptLoaded(key);
      }

      await _loadUserLocation();
      await _refreshMarkers();
      if (mounted) {
        setState(() => _isLoading = false);
        _refreshTimer ??= Timer.periodic(
          const Duration(seconds: 20),
          (_) => _refreshMarkers(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo inicializar el mapa: $e';
          _isLoading = false;
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
          setState(() => _error = 'Activa el servicio de ubicacion para ver el mapa.');
          return;
        }
      }

      PermissionStatus permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
        if (permission != PermissionStatus.granted &&
            permission != PermissionStatus.grantedLimited) {
          setState(() => _error = 'Se requieren permisos de ubicacion.');
          return;
        }
      }

      final currentLocation = await _location.getLocation();
      if (currentLocation.latitude != null && currentLocation.longitude != null) {
        final latLng = LatLng(currentLocation.latitude!, currentLocation.longitude!);
        setState(() => _userPosition = latLng);
        _moveCamera(latLng, zoom: 15);
      }

      _locationSubscription?.cancel();
      _locationSubscription = _location.onLocationChanged.listen((event) {
        if (event.latitude != null && event.longitude != null) {
          final latLng = LatLng(event.latitude!, event.longitude!);
          setState(() => _userPosition = latLng);
        }
      });
    } catch (e) {
      setState(() => _error = 'No se pudo obtener tu ubicacion: $e');
    }
  }

  Future<void> _refreshMarkers() async {
    try {
      final db = context.read<DatabaseService>();
      final session = context.read<SessionController>();
      final usuario = session.usuario;

      List<Pedido> pedidos = [];

      if (!usuario.isGuest) {
        switch (usuario.rol) {
          case 'delivery':
            pedidos = await db.getPedidosPorDelivery(usuario.idUsuario);
            break;
          case 'admin':
          case 'soporte':
            pedidos = await db.getPedidosPorEstado('en camino');
            break;
          default:
            pedidos = await db.getPedidos(usuario.idUsuario);
            pedidos = pedidos
                .where((p) => p.estado != 'entregado' && p.estado != 'cancelado')
                .toList();
        }
      }

      final markers = <Marker>{};
      if (_userPosition != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('usuario_actual'),
            position: _userPosition!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: const InfoWindow(title: 'Estas aqui'),
          ),
        );
      }

      final pedidosEnRuta = pedidos.where((p) => p.idDelivery != null).toList();
      if (pedidosEnRuta.isNotEmpty) {
        final futures = pedidosEnRuta.map((pedido) async {
          final ubicacion = await db.getRepartidorLocation(pedido.idPedido);
          return (pedido, ubicacion);
        });

        final results = await Future.wait(futures);
        for (final (pedido, ubicacion) in results) {
          if (ubicacion == null) continue;
          final lat = _parseDouble(ubicacion['latitud'] ?? ubicacion['lat']);
          final lon = _parseDouble(ubicacion['longitud'] ?? ubicacion['lng']);
          if (lat == null || lon == null) continue;

          final markerId = MarkerId('delivery_${pedido.idDelivery}_${pedido.idPedido}');
          markers.add(
            Marker(
              markerId: markerId,
              position: LatLng(lat, lon),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              infoWindow: InfoWindow(
                title: 'Repartidor #${pedido.idDelivery}',
                snippet: 'Pedido ${pedido.idPedido} · ${pedido.estado}',
              ),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _markers = markers;
          _error = markers.isEmpty ? 'Sin repartidores activos por el momento.' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error al actualizar el mapa: $e');
      }
    }
  }

  double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _moveCamera(LatLng target, {double zoom = 13}) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: zoom)),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _locationSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markers = _markers;
    final error = _error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa en tiempo real'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _userPosition ?? _esmeraldasCenter,
                    zoom: _userPosition != null ? 14 : 12,
                  ),
                  markers: markers,
                  myLocationEnabled: _userPosition != null,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: (controller) => _mapController = controller,
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: _buildInfoCard(markers.length, error),
                ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'center-map',
            onPressed: () {
              final target = _userPosition ?? _esmeraldasCenter;
              _moveCamera(target, zoom: _userPosition != null ? 15 : 12);
            },
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'refresh-map',
            onPressed: _refreshMarkers,
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(int markerCount, String? error) {
    final message = error ??
        (markerCount <= 1
            ? 'Mapa centrado en Esmeraldas.\nAguardando repartidores activos.'
            : 'Mostrando $markerCount puntos activos en tiempo real.');

    return Card(
      elevation: 4,
      color: Colors.white,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
