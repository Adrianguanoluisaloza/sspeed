import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/pedido.dart';
import 'package:flutter_application_2/models/usuario.dart';
import 'package:flutter_application_2/services/database_service.dart';
import 'package:provider/provider.dart' show Provider;

import 'package:intl/intl.dart';

import '../routes/app_routes.dart';

import '../routes/app_routes.dart';

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
    // Solo cargamos los pedidos si el usuario está autenticado.
    if (widget.usuario.isAuthenticated) {
      _pedidosFuture = Provider.of<DatabaseService>(context, listen: false)
          .getPedidos(widget.usuario.idUsuario);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.usuario.isGuest) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mis Pedidos'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long,
                    size: 96, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                const Text(
                  'Inicia sesión para ver tu historial',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aquí aparecerán tus pedidos completados y en curso.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.login),
                  child: const Text('Iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Pedidos'),
      ),
      body: FutureBuilder<List<Pedido>>(
        future: _pedidosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar pedidos: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Aún no has realizado ningún pedido.', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          final pedidos = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: pedidos.length,
            itemBuilder: (context, index) {
              return OrderCard(pedido: pedidos[index]);
            },
          );
        },
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final Pedido pedido;
  const OrderCard({super.key, required this.pedido});

  // Helper para obtener color y icono según el estado
  (Color, IconData) _getStatusInfo(String estado) {
    switch (estado.toLowerCase()) {
      case 'entregado':
        return (Colors.green, Icons.check_circle);
      case 'en camino':
        return (Colors.blue, Icons.local_shipping);
      case 'cancelado':
        return (Colors.red, Icons.cancel);
      default: // pendiente, en preparacion
        return (Colors.orange, Icons.pending_actions);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusIcon) = _getStatusInfo(pedido.estado);
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(pedido.fechaPedido);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pedido #${pedido.idPedido}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('\$${pedido.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepOrange)),
              ],
            ),
            const Divider(height: 20),
            Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  pedido.estado.toUpperCase(),
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
             const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, color: Colors.grey.shade600, size: 16),
                const SizedBox(width: 4),
                Expanded(child: Text(pedido.direccionEntrega, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
              ],
            )
          ],
        ),
      ),
    );
  }
}

