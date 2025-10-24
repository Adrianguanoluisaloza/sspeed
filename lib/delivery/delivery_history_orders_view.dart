import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pedido.dart';
import '../models/usuario.dart';
import '../services/database_service.dart';

class DeliveryHistoryOrdersView extends StatefulWidget {
  final Usuario deliveryUser;
  const DeliveryHistoryOrdersView({super.key, required this.deliveryUser});

  @override
  State<DeliveryHistoryOrdersView> createState() => _DeliveryHistoryOrdersViewState();
}

class _DeliveryHistoryOrdersViewState extends State<DeliveryHistoryOrdersView> {
  late Future<List<Pedido>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  Future<List<Pedido>> _loadHistory() async {
    final pedidos = await Provider.of<DatabaseService>(context, listen: false)
        .getPedidosPorDelivery(widget.deliveryUser.idUsuario);
    // Filtramos solo los completados para mantener el mismo origen de datos.
    return pedidos
        .where((pedido) {
          final estado = pedido.estado.toLowerCase();
          return estado.contains('entregado') || estado.contains('completado');
        })
        .toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _historyFuture = _loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Pedido>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('No pudimos cargar tu historial.'));
        }
        final pedidos = snapshot.data ?? [];
        if (pedidos.isEmpty) {
          return const Center(child: Text('Sin entregas completadas todavía.'));
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            itemCount: pedidos.length,
            itemBuilder: (context, index) {
              final pedido = pedidos[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text('Pedido #${pedido.idPedido}'),
                  subtitle: Text(
                    'Total: \$${pedido.total.toStringAsFixed(2)}\nEstado: ${pedido.estado}',
                  ),
                  leading: const Icon(Icons.history, color: Colors.deepOrange),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
