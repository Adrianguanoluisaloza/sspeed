import 'package:flutter/material.dart';
import '../models/pedido.dart';
import '../models/pedido_detalle.dart';
import '../services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' show Provider;

class OrderDetailScreen extends StatefulWidget {
  final int idPedido;
  const OrderDetailScreen({super.key, required this.idPedido});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<PedidoDetalle?> _detailsFuture;
  late Future<Map<String, dynamic>?> _trackingFuture;
  late DatabaseService _databaseService;

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _detailsFuture = _databaseService.getPedidoDetalle(widget.idPedido);
    _trackingFuture = _databaseService.getRepartidorLocation(widget.idPedido);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles del Pedido #${widget.idPedido}'),
      ),
      body: FutureBuilder<PedidoDetalle?>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Puedes usar un Shimmer aquí para una carga más elegante
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    const Text('No se pudieron cargar los detalles del pedido.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _detailsFuture = _databaseService.getPedidoDetalle(widget.idPedido);
                          _trackingFuture = _databaseService.getRepartidorLocation(widget.idPedido);
                        });
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Pedido no encontrado.'));
          }

          final pedidoDetalle = snapshot.data!;
          final pedido = pedidoDetalle.pedido;
          final detalles = pedidoDetalle.detalles;
          final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(pedido.fechaPedido);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _detailsFuture = _databaseService.getPedidoDetalle(widget.idPedido);
                _trackingFuture = _databaseService.getRepartidorLocation(widget.idPedido);
              });
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              children: [
                _buildSummaryCard(context, pedido, formattedDate),
                const SizedBox(height: 24),
                const Text('Seguimiento del Pedido',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildOrderTimeline(pedido.estado),
                const SizedBox(height: 16),
                _buildTrackingCard(),
                const SizedBox(height: 24),
                const Text('Productos en tu pedido',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: detalles.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final item = detalles[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: _OrderItemImage(imageUrl: item.imagenUrl),
                        ),
                        title: Text(item.nombreProducto),
                        subtitle: Text(
                            'Cant: ${item.cantidad} x \$${item.precioUnitario.toStringAsFixed(2)}'),
                        trailing: Text('\$${item.subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildSummaryCard(
      BuildContext context, Pedido pedido, String formattedDate) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fecha: $formattedDate'),
            const SizedBox(height: 8),
            Text('Dirección: ${pedido.direccionEntrega}'),
            if (pedido.latitudDestino != null && pedido.longitudDestino != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Coordenadas destino: ${pedido.latitudDestino!.toStringAsFixed(4)}, '
                  '${pedido.longitudDestino!.toStringAsFixed(4)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL PAGADO', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('\$${pedido.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTimeline(String estadoActual) {
    final estados = ['pendiente', 'en preparacion', 'en camino', 'entregado'];
    int estadoIndex = estados.indexOf(estadoActual.toLowerCase());

    // Si el estado es cancelado, mostramos un estado especial
    if (estadoActual.toLowerCase() == 'cancelado') {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: TimelineTile(
            icon: Icons.cancel,
            title: 'Pedido Cancelado',
            subtitle: 'Este pedido fue cancelado.',
            isDone: true,
            isLast: true, // Para no dibujar la línea de abajo
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            TimelineTile(icon: Icons.pending_actions, title: 'Pedido Pendiente', subtitle: 'Confirmando tu orden.', isDone: estadoIndex >= 0),
            TimelineTile(icon: Icons.restaurant_menu, title: 'En Preparación', subtitle: 'El restaurante está preparando tu comida.', isDone: estadoIndex >= 1),
            TimelineTile(icon: Icons.local_shipping, title: 'En Camino', subtitle: 'Tu pedido va en camino a tu dirección.', isDone: estadoIndex >= 2),
            TimelineTile(icon: Icons.check_circle, title: 'Entregado', subtitle: '¡Disfruta tu comida!', isDone: estadoIndex >= 3, isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingCard() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _trackingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Expanded(child: Text('Actualizando ubicación del repartidor...')),
                ],
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.location_disabled, color: Colors.redAccent),
              title: const Text('No se pudo obtener la ubicación del repartidor'),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    _trackingFuture =
                        _databaseService.getRepartidorLocation(widget.idPedido);
                  });
                },
              ),
            ),
          );
        }
        final ubicacion = snapshot.data;
        if (ubicacion == null) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.location_searching, color: Colors.orange),
              title: const Text('Ubicación no disponible'),
              subtitle: const Text('El repartidor aún no ha compartido su posición.'),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    _trackingFuture =
                        _databaseService.getRepartidorLocation(widget.idPedido);
                  });
                },
              ),
            ),
          );
        }
        final lat = (ubicacion['latitud'] as num?)?.toDouble();
        final lon = (ubicacion['longitud'] as num?)?.toDouble();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.navigation, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text('Seguimiento en tiempo real',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        setState(() {
                          _trackingFuture = _databaseService
                              .getRepartidorLocation(widget.idPedido);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade100, Colors.teal.shade200],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          lat != null && lon != null
                              ? 'Lat: ${lat.toStringAsFixed(4)}, Lon: ${lon.toStringAsFixed(4)}'
                              : 'Coordenadas no disponibles',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        if (ubicacion['actualizado'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              'Última actualización: ${ubicacion['actualizado']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- COMPONENTE PARA LA LÍNEA DE TIEMPO ---
class TimelineTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDone;
  final bool isLast;

  const TimelineTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDone,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, color: isDone ? Theme.of(context).primaryColor : Colors.grey, size: 28),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: isDone ? Theme.of(context).primaryColor : Colors.grey.shade300,
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDone ? Colors.black : Colors.grey)),
                  Text(subtitle, style: TextStyle(color: isDone ? Colors.black54 : Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemImage extends StatelessWidget {
  final String? imageUrl;

  const _OrderItemImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    return Image.network(
      imageUrl!,
      width: 50,
      height: 50,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: const Icon(Icons.fastfood, color: Colors.grey),
    );
  }
}

