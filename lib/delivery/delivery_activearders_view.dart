import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/pedido.dart';
import 'package:flutter_application_2/models/usuario.dart';
import 'package:flutter_application_2/services/database_service.dart';
import 'package:provider/provider.dart';
import 'dart:async' show Future, Timer;
import 'package:location/location.dart';

import '../routes/app_routes.dart';

class DeliveryActiveOrdersView extends StatefulWidget {
  final Usuario deliveryUser;
  const DeliveryActiveOrdersView({super.key, required this.deliveryUser});

  @override
  State<DeliveryActiveOrdersView> createState() =>
      _DeliveryActiveOrdersViewState();
}

class _DeliveryActiveOrdersViewState extends State<DeliveryActiveOrdersView> {
  late Future<List<Pedido>> _pedidosFuture;
  DatabaseService? _databaseService; // Para usar en el Timer

  // --- 5. Variables para el Tracking de Ubicación ---
  Timer? _locationTimer;
  Location location = Location();
  bool _serviceEnabled = false;
  PermissionStatus _permissionGranted = PermissionStatus.denied;
  LocationData? _currentLocation;
  // --------------------------------------------------

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _loadPedidos();
  }

  @override
  void dispose() {
    // 6. Detener el timer al salir de la pantalla
    _stopLocationTimer();
    super.dispose();
  }

  void _loadPedidos() {
    _pedidosFuture = _databaseService!
        // 7. CORREGIDO: Usar el método correcto
        .getPedidosPorDelivery(widget.deliveryUser.idUsuario)
        .then((pedidos) {
      // 8. Iniciar o detener el tracking basado en si hay pedidos
      if (pedidos.isNotEmpty) {
        _startLocationTracking();
      } else {
        _stopLocationTimer();
      }
      return pedidos;
    });
  }

  // --- 9. Lógica para Iniciar el Servicio de Localización ---
  Future<void> _startLocationTracking() async {
    // Si el timer ya está activo, no hacer nada
    if (_locationTimer != null && _locationTimer!.isActive) return;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        debugPrint('Servicio de localización deshabilitado.');
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        debugPrint('Permiso de localización denegado.');
        return;
      }
    }

    // Configurar para alta precisión
    await location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 10000, // 10 segundos
      distanceFilter: 10, // 10 metros
    );

    // Iniciar el timer que envía la ubicación cada 30 segundos
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _sendCurrentLocation();
    });
    // Enviar ubicación inmediatamente al iniciar
    _sendCurrentLocation();
  }

  /// Envía la ubicación actual al backend
  Future<void> _sendCurrentLocation() async {
    try {
      _currentLocation = await location.getLocation();
      if (_currentLocation != null && _databaseService != null) {
        debugPrint(
            ' Enviando ubicación: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
        // 10. CORREGIDO: Usar el método de servicio
        await _databaseService!.updateRepartidorLocation(
          widget.deliveryUser.idUsuario,
          _currentLocation!.latitude!,
          _currentLocation!.longitude!,
        );
      }
    } catch (e) {
      debugPrint('Error al obtener/enviar ubicación: $e');
      // Si se deniegan permisos mientras corre, detener el timer
      if (e.toString().contains('PERMISSION_DENIED')) {
        _stopLocationTimer();
      }
    }
  }

  /// Detiene el timer de localización
  void _stopLocationTimer() {
    _locationTimer?.cancel();
    _locationTimer = null;
    debugPrint('🛑 Tracking de ubicación detenido.');
  }
  // --- Fin de la lógica de Localización ---

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
                  subtitle: Text('Dirección: ${pedido.direccionEntrega}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    // 11. CORREGIDO: Navegar a la pantalla de detalle
                    // El repartidor puede ver el detalle (igual que el cliente)
                    // para ver los productos o el mapa de su propio tracking
                    await Navigator.of(context).pushNamed(
                      AppRoutes.orderDetail,
                      arguments: pedido.idPedido,
                    );

                    if (!mounted) return;
                    // 12. Refrescar la lista al volver usando la ruta centralizada.
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
