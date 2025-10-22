import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/pedido_detalle.dart';
import 'package:flutter_application_2/services/database_service.dart';
import 'package:provider/provider.dart';

class AdminOrderDetailScreen extends StatefulWidget {
  final int idPedido;
  const AdminOrderDetailScreen({super.key, required this.idPedido});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  late Future<PedidoDetalle?> _detailsFuture;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _detailsFuture = Provider.of<DatabaseService>(context, listen: false)
        .getPedidoDetalle(widget.idPedido);
  }

  Future<void> _updateStatus(String nuevoEstado) async {
    setState(() => _isUpdating = true);
    final success = await Provider.of<DatabaseService>(context, listen: false)
        .updatePedidoEstado(widget.idPedido, nuevoEstado);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Estado actualizado a "$nuevoEstado"' : 'Error al actualizar'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
      setState(() {
        _isUpdating = false;
        // Si fue exitoso, salimos de la pantalla y devolvemos 'true' para refrescar
        if (success) {
          Navigator.pop(context, true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestionar Pedido #${widget.idPedido}'),
      ),
      body: FutureBuilder<PedidoDetalle?>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('No se pudieron cargar los detalles.'));
          }

          final pedidoDetalle = snapshot.data!;
          final estadoActual = pedidoDetalle.pedido.estado;

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  _buildOrderTimeline(estadoActual), // <-- ESTA LLAMADA AHORA FUNCIONARÁ
                  const SizedBox(height: 24),
                  const Text('Productos del pedido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pedidoDetalle.detalles.length,
                      itemBuilder: (context, index) {
                        final item = pedidoDetalle.detalles[index];
                        return ListTile(
                          title: Text(item.nombreProducto),
                          subtitle: Text('Cant: ${item.cantidad}'),
                          trailing: Text('\$${item.subtotal.toStringAsFixed(2)}'),
                        );
                      },
                    ),
                  )
                ],
              ),
              if (estadoActual == 'pendiente' || estadoActual == 'en preparacion')
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.all(16),
          color: Theme.of(context).primaryColor.withValues(alpha:0.95),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isUpdating ? null : () {
                          final proximoEstado = estadoActual == 'pendiente' ? 'en preparacion' : 'en camino';
                          _updateStatus(proximoEstado);
                        },
                        child: _isUpdating
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                            : Text(estadoActual == 'pendiente' ? 'Confirmar y Preparar' : 'Marcar como "En Camino"'),
                      ),
                    ),
                  ),
                )
            ],
          );
        },
      ),
    );
  }

  // --- MÉTODO QUE FALTABA ---
  Widget _buildOrderTimeline(String estadoActual) {
    final estados = ['pendiente', 'en preparacion', 'en camino', 'entregado'];
    int estadoIndex = estados.indexOf(estadoActual.toLowerCase());

    if (estadoActual.toLowerCase() == 'cancelado') {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: TimelineTile(
            icon: Icons.cancel,
            title: 'Pedido Cancelado',
            subtitle: 'Este pedido fue cancelado.',
            isDone: true,
            isLast: true,
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

// --- WIDGET AUXILIAR QUE FALTABA ---
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

