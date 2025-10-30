import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_application_2/models/pedido.dart';
import 'package:flutter_application_2/models/usuario.dart';
import 'package:flutter_application_2/services/database_service.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'dart:async' show Future, Timer;

import '../routes/app_routes.dart';

class DeliveryActiveOrdersView extends StatefulWidget {
  final Usuario deliveryUser;
  const DeliveryActiveOrdersView({super.key, required this.deliveryUser});

  @override
  State<DeliveryActiveOrdersView> createState() => _DeliveryActiveOrdersViewState();
}

class _DeliveryActiveOrdersViewState extends State<DeliveryActiveOrdersView> {
  late Future<List<Pedido>> _pedidosFuture;
  DatabaseService? _databaseService;

  // Variables de tracking de ubicacion
  Timer? _locationTimer;
  Location location = Location();
  bool _serviceEnabled = false;
  PermissionStatus _permissionGranted = PermissionStatus.denied;
  LocationData? _currentLocation;

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _loadPedidos();
  }

  @override
  void dispose() {
    _stopLocationTimer();
    super.dispose();
  }

  void _loadPedidos() {
    _pedidosFuture = _databaseService!
        .getPedidosPorDelivery(widget.deliveryUser.idUsuario)
        .then((pedidos) {
      if (pedidos.isNotEmpty) {
        _startLocationTracking();
      } else {
        _stopLocationTimer();
      }
      return pedidos;
    });
  }

  // Inicia seguimiento de ubicacion (solo mobile)
  Future<void> _startLocationTracking() async {
    if (kIsWeb) {
      _stopLocationTimer();
      debugPrint('Tracking de ubicacion deshabilitado en Web.');
      return;
    }
    if (_locationTimer != null && _locationTimer!.isActive) return;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        debugPrint('Servicio de ubicacion deshabilitado.');
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        debugPrint('Permiso de ubicacion denegado.');
        return;
      }
    }

    await location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 10000,
      distanceFilter: 10,
    );

    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _sendCurrentLocation();
    });
    _sendCurrentLocation();
  }

  // Envia ubicacion actual al backend
  Future<void> _sendCurrentLocation() async {
    try {
      if (kIsWeb) return;
      _currentLocation = await location.getLocation();
      if (_currentLocation != null && _databaseService != null) {
        debugPrint(
            'Enviando ubicacion: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
        await _databaseService!.updateRepartidorLocation(
          widget.deliveryUser.idUsuario,
          _currentLocation!.latitude!,
          _currentLocation!.longitude!,
        );
      }
    } catch (e) {
      debugPrint('Error al obtener/enviar ubicacion: $e');
      if (e.toString().contains('PERMISSION_DENIED')) {
        _stopLocationTimer();
      }
    }
  }

  void _stopLocationTimer() {
    _locationTimer?.cancel();
    _locationTimer = null;
    debugPrint('🛑 Tracking de ubicacion detenido.');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Pedido>>(
      future: _pedidosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error al cargar tus entregas.'));
        }
        final pedidos = snapshot.data ?? [];
        if (pedidos.isEmpty) {
          return const Center(child: Text('No tienes entregas activas.'));
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() => _loadPedidos()),
          child: ListView.builder(
            itemCount: pedidos.length,
            itemBuilder: (context, index) {
              final pedido = pedidos[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(
                      'Pedido #${pedido.idPedido} - ${pedido.estado.toUpperCase()}'),
                  subtitle: Text('Direccion: ${pedido.direccionEntrega}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).pushNamed(
                      AppRoutes.orderDetail,
                      arguments: pedido.idPedido,
                    );
                    if (!mounted) return;
                    setState(() => _loadPedidos());
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

