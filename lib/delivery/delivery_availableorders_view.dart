import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/pedido.dart';
import '../models/usuario.dart';
import '../services/database_service.dart';

class DeliveryAvailableOrdersView extends StatefulWidget {
  final Usuario deliveryUser;
  final void Function(int count) onOrderCountChanged;

  const DeliveryAvailableOrdersView({
    super.key,
    required this.deliveryUser,
    required this.onOrderCountChanged,
  });
  @override
  State<DeliveryAvailableOrdersView> createState() => _DeliveryAvailableOrdersViewState();
}

class _DeliveryAvailableOrdersViewState extends State<DeliveryAvailableOrdersView> {
  late Future<List<Pedido>> _pedidosFuture;

  @override
  void initState() {
    super.initState();
    if (widget.deliveryUser.isAuthenticated) {
      _loadPedidos();
    }
  }

  void _loadPedidos() {
    if (mounted && widget.deliveryUser.isAuthenticated) {
      setState(() {
        _pedidosFuture = Provider.of<DatabaseService>(context, listen: false).getPedidosDisponibles();
      });
    }
  }

  Future<void> _acceptOrder(int idPedido) async {
    if (!mounted) return;

    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final success = await dbService.asignarPedido(idPedido, widget.deliveryUser.idUsuario);

    if (mounted) {
      messenger.showSnackBar(SnackBar(
        content: Text(success ? 'Pedido aceptado. Revisa "Mis Entregas"' : 'El pedido ya fue tomado.'),
        backgroundColor: success ? Colors.green : Colors.orange,
      ));
      if (success) {
        _loadPedidos();
      }
    }
  }

  // CORRECCIÓN: Se refactoriza el `build` para ser más robusto y seguro.
  @override
  Widget build(BuildContext context) {
    if (!widget.deliveryUser.isAuthenticated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Debes iniciar sesión para ver pedidos disponibles', style: TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                onPressed: () => Navigator.of(context).pushNamed('/login'),
                label: const Text('Iniciar sesión'),
              ),
            ],
          ),
        ),
      );
    }
    return FutureBuilder<List<Pedido>>(
      future: _pedidosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error);
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyView();
        }
        final pedidos = snapshot.data!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onOrderCountChanged(pedidos.length);
        });
        return RefreshIndicator(
          onRefresh: () async => _loadPedidos(),
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: pedidos.length,
            itemBuilder: (context, index) {
              final pedido = pedidos[index];
              return _OrderCard(pedido: pedido, onAccept: () => _acceptOrder(pedido.idPedido));
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No hay pedidos disponibles por ahora', style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPedidos,
            label: const Text('Refrescar'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const Text('Error al Cargar Pedidos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Detalle: ${error.toString()}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(icon: const Icon(Icons.refresh), onPressed: _loadPedidos, label: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Pedido pedido;
  final VoidCallback onAccept;

  const _OrderCard({required this.pedido, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd MMM, hh:mm a').format(pedido.fechaPedido);
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Pedido #${pedido.idPedido}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('\$${pedido.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
            ]),
            const Divider(height: 20),
            Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.location_on_outlined, color: Colors.grey.shade600, size: 16),
              const SizedBox(width: 4),
              Expanded(child: Text(pedido.direccionEntrega, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
            ]),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onAccept, child: const Text('Aceptar Pedido'))),
          ],
        ),
      ),
    );
  }
}
