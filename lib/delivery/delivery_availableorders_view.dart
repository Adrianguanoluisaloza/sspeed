import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/pedido.dart';
import 'package:flutter_application_2/models/usuario.dart';
import 'package:flutter_application_2/services/database_service.dart';
import 'package:provider/provider.dart';


class DeliveryAvailableOrdersView extends StatefulWidget {
  final Usuario deliveryUser;
  const DeliveryAvailableOrdersView({super.key, required this.deliveryUser});

  @override
  State<DeliveryAvailableOrdersView> createState() => _DeliveryAvailableOrdersViewState();
}

class _DeliveryAvailableOrdersViewState extends State<DeliveryAvailableOrdersView> {
  late Future<List<Pedido>> _pedidosFuture;

  @override
  void initState() {
    super.initState();
    _loadPedidos();
  }

  void _loadPedidos() {
    _pedidosFuture = Provider.of<DatabaseService>(context, listen: false).getPedidosDisponibles();
  }

  Future<void> _acceptOrder(int idPedido) async {
    final success = await Provider.of<DatabaseService>(context, listen: false)
        .asignarPedido(idPedido, widget.deliveryUser.idUsuario);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Pedido aceptado. Revisa "Mis Entregas"' : 'El pedido ya fue tomado.'),
      ));
      if (success) {
        setState(() {
          _loadPedidos(); // Refresca la lista de disponibles
        });
      }
    }
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
          return const Center(child: Text('Error al cargar pedidos.'));
        }
        final pedidos = snapshot.data ?? [];
        if (pedidos.isEmpty) {
          return const Center(child: Text('No hay pedidos disponibles.'));
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
                  title: Text('Pedido #${pedido.idPedido}'),
                  subtitle: Text('Dirección: ${pedido.direccionEntrega}\nTotal: \$${pedido.total.toStringAsFixed(2)}'),
                  trailing: ElevatedButton(
                    onPressed: () => _acceptOrder(pedido.idPedido),
                    child: const Text('Aceptar'),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
