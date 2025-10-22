import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/pedido_detalle.dart';
import 'package:flutter_application_2/services/database_service.dart';
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

  @override
  void initState() {
    super.initState();
    _detailsFuture = Provider.of<DatabaseService>(context, listen: false)
        .getPedidoDetalle(widget.idPedido);
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
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('No se pudieron cargar los detalles del pedido.'));
          }

          final pedidoDetalle = snapshot.data!;
          final pedido = pedidoDetalle.pedido;
          final detalles = pedidoDetalle.detalles;
          final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(pedido.fechaPedido);

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            children: [
              // --- SECCIÓN DE RESUMEN ---
              _buildSummaryCard(context, pedido, formattedDate),

              const SizedBox(height: 24),
              const Text('Seguimiento del Pedido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // --- LÍNEA DE TIEMPO DEL PEDIDO ---
              _buildOrderTimeline(pedido.estado),

              const SizedBox(height: 24),
              const Text('Productos en tu pedido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // --- LISTA DE PRODUCTOS ---
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
                        child: Image.network(
                          item.imagenUrl,
                          width: 50, height: 50, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 50, height: 50, color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported)),
                        ),
                      ),
                      title: Text(item.nombreProducto),
                      subtitle: Text('Cant: ${item.cantidad} x \$${item.precioUnitario.toStringAsFixed(2)}'),
                      trailing: Text('\$${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildSummaryCard(BuildContext context, dynamic pedido, String formattedDate) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fecha: $formattedDate'),
            const SizedBox(height: 8),
            Text('Dirección: ${pedido.direccionEntrega}'),
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
