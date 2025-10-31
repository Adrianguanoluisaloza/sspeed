import 'package:flutter/material.dart';
import 'package:flutter_application_2/services/database_service.dart';
import 'package:flutter_application_2/models/usuario.dart';
import 'package:provider/provider.dart';

// Modelo simple para simular el estado del pedido.
// Lo cambiaremos a String para que coincida con los datos del backend.
// enum OrderStatus { confirmado, preparacion, en_camino, entregado }

class OrderTrackingScreen extends StatefulWidget {
  // Recibimos el ID del pedido para hacerlo dinámico.
  final int orderId;
  const OrderTrackingScreen({super.key, this.orderId = 1001});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  bool _isLoading = true;
  String _currentStatus = 'pendiente'; // Estado inicial por defecto
  // MEJORA: Se añade el estado para guardar la información del repartidor.
  Usuario? _repartidor;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchOrderStatus();
  }

  // AHORA USAREMOS LA LLAMADA REAL A LA API
  Future<void> _fetchOrderStatus() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _repartidor = null;
    });

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      // Usamos el método que ya existe en tu DatabaseService
      final pedidoDetalle = await dbService.getPedidoDetalle(widget.orderId);

      if (mounted && pedidoDetalle != null) {
        setState(() {
          _currentStatus = pedidoDetalle.pedido.estado.toLowerCase();
        });

        // MEJORA: Si hay un repartidor asignado, obtenemos sus datos.
        final idDelivery = pedidoDetalle.pedido.idDelivery;
        if (idDelivery != null) {
          final repartidorInfo = await dbService.getUsuarioById(idDelivery);
          if (mounted) {
            setState(() => _repartidor = repartidorInfo);
          }
        }
      } else if (mounted) {
        setState(() => _errorMessage = 'No se pudo encontrar el pedido.');
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _errorMessage = 'Error al cargar el estado: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Seguimiento de Pedido #${widget.orderId}'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          // Botón para refrescar el estado
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _fetchOrderStatus)
        ],
      ),
      body: _errorMessage != null
          // Mostramos un error si algo falla
          ? Center(
              child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_errorMessage!,
                        style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                        onPressed: _fetchOrderStatus,
                        child: const Text('Reintentar'))
                  ]),
            ))
          // Si no hay error, mostramos el contenido
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 1. Simulación de Mapa Estático
                  _buildMapPlaceholder(context),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Estado del Delivery',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange),
                        ),
                        if (_isLoading)
                          const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 3)),
                      ],
                    ),
                  ),

                  // 2. Timeline del Pedido (ahora dinámico)
                  _buildOrderTimeline(_currentStatus),

                  // MEJORA: Solo se muestra si el pedido está en un estado relevante.
                  if (_currentStatus == 'en camino' ||
                      _currentStatus == 'entregado')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 0),
                          child: Text('Detalles del Repartidor',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange)),
                        ),
                        _buildDriverInfo(),
                      ],
                    ),

                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  // Widget de Mapa (Simulación, ya que el tracking real es complejo)
  Widget _buildMapPlaceholder(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: const Stack(
        alignment: Alignment.center,
        children: [
          // Fondo de mapa
          Text('MAPA ESTÁTICO DE RUTA',
              style: TextStyle(color: Colors.black54, fontSize: 16)),

          // Icono del repartidor
          Positioned(
            top: 50,
            left: 50,
            child: Icon(Icons.motorcycle, size: 40, color: Colors.red),
          ),

          // Icono del destino
          Positioned(
            bottom: 50,
            right: 50,
            child: Icon(Icons.location_on, size: 40, color: Colors.green),
          ),
        ],
      ),
    );
  }

  // Widget de línea de tiempo del pedido
  Widget _buildOrderTimeline(String status) {
    // Definimos el orden de los estados para la línea de tiempo
    final statusOrder = [
      'confirmado',
      'en preparacion',
      'en camino',
      'entregado'
    ];
    // 'pendiente' se considera como el paso 0 (confirmado pero no avanzado)
    int currentStep = statusOrder.indexOf(status.toLowerCase());
    if (currentStep == -1 && status.toLowerCase() == 'pendiente') {
      currentStep = 0;
    }

    return Column(
      children: [
        TimelineTile(
          icon: Icons.check_circle,
          title: 'Pedido Confirmado',
          subtitle: 'Esperando que el restaurante lo prepare.',
          isDone: currentStep >= 0,
        ),
        TimelineTile(
          icon: Icons.restaurant_menu,
          title: 'En Preparación',
          subtitle: 'El restaurante está cocinando tu comida.',
          isDone: currentStep >= 1,
        ),
        TimelineTile(
          icon: Icons.motorcycle,
          title: 'En Camino',
          subtitle: 'El repartidor está cerca de tu ubicación.',
          isDone: currentStep >= 2,
        ),
        TimelineTile(
          icon: Icons.home,
          title: 'Entregado',
          subtitle: '¡Disfruta tu pedido!',
          isDone: currentStep >= 3,
        ),
      ],
    );
  }

  // Widget con información del repartidor
  Widget _buildDriverInfo() {
    // MEJORA: Muestra un estado de carga o el nombre real del repartidor.
    if (_isLoading) {
      return const Card(
        margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: ListTile(
            leading: CircularProgressIndicator(),
            title: Text('Buscando repartidor...')),
      );
    }

    final repartidor = _repartidor;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=delivery'),
          backgroundColor: Colors.green,
        ),
        title: Text(repartidor != null
            ? 'Repartidor: ${repartidor.nombre}'
            : 'Sin repartidor asignado'),
        subtitle: repartidor != null
            ? const Text('Vehículo: Moto (Placa: ABC-123)')
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.phone, color: Colors.green),
          onPressed: () {
            // Simular llamada
          },
        ),
      ),
    );
  }
}

// Componente auxiliar para la línea de tiempo
class TimelineTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDone;

  const TimelineTile(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, color: isDone ? Colors.green : Colors.grey, size: 30),
              // El último tile no necesita línea de conexión hacia abajo
              if (title != 'Entregado')
                Container(
                  width: 2,
                  height: 40,
                  color: isDone ? Colors.green : Colors.grey.shade300,
                ),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDone ? Colors.black : Colors.grey,
                  ),
                ),
                Text(subtitle,
                    style: TextStyle(
                        color: isDone ? Colors.black54 : Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
