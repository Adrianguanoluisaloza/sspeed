import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/pedido.dart';
import '../models/usuario.dart';
import '../routes/app_routes.dart';
import '../services/database_service.dart';
import 'order_detail_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  final Usuario usuario;
  const OrderHistoryScreen({super.key, required this.usuario});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late Future<List<Pedido>> _pedidosFuture;

  @override
  void initState() {
    super.initState();
    if (widget.usuario.isAuthenticated) {
      _loadOrders();
    }
  }

  void _loadOrders() {
    setState(() {
      _pedidosFuture = Provider.of<DatabaseService>(context, listen: false)
          .getPedidos(widget.usuario.idUsuario);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Pedidos'),
      ),
      body: widget.usuario.isGuest
          ? _buildLoggedOutView(context)
          : _buildOrderList(context),
    );
  }

  Widget _buildLoggedOutView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long,
                size: 96,
                color: Theme.of(context).colorScheme.primary.withAlpha(179)),
            const SizedBox(height: 24),
            const Text('Inicia sesión para ver tu historial',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
                'Aquí aparecerán todos tus pedidos completados y en curso.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.login),
                child: const Text('Iniciar Sesión')),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(BuildContext context) {
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
        return RefreshIndicator(
          onRefresh: () async => _loadOrders(),
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: pedidos.length,
            itemBuilder: (context, index) {
              return OrderCard(pedido: pedidos[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey),
        const SizedBox(height: 16),
        const Text('Aún no has realizado ningún pedido.',
            style: TextStyle(fontSize: 18, color: Colors.grey)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            label: const Text('Refrescar'))
      ]),
    );
  }

  Widget _buildErrorView(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          const Text('Error al Cargar Pedidos',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              onPressed: _loadOrders,
              label: const Text('Reintentar')),
        ]),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final Pedido pedido;
  const OrderCard({super.key, required this.pedido});

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        DateFormat('dd MMM yyyy, hh:mm a').format(pedido.fechaPedido);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (context) =>
                    OrderDetailScreen(idPedido: pedido.idPedido)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Pedido #${pedido.idPedido}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text('\$${pedido.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green)),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(formattedDate,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                _StatusChip(status: pedido.estado),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;
    switch (status.toLowerCase()) {
      case 'entregado':
        color = Colors.green;
        label = 'Entregado';
        icon = Icons.check_circle_outline;
        break;
      case 'en camino':
        color = Colors.blue;
        label = 'En Camino';
        icon = Icons.local_shipping_outlined;
        break;
      case 'cancelado':
        color = Colors.red;
        label = 'Cancelado';
        icon = Icons.cancel_outlined;
        break;
      default:
        color = Colors.orange;
        label = 'Pendiente';
        icon = Icons.pending_actions_outlined;
    }
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color.withAlpha(38),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}
