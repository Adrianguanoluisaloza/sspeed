import 'package:flutter/material.dart';
import 'package:flutter_application_2/admin/admin_order_detail_screen.dart';
import 'package:flutter_application_2/models/pedido.dart';
import 'package:flutter_application_2/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminOrdersView extends StatefulWidget {
  const AdminOrdersView({super.key});

  @override
  State<AdminOrdersView> createState() => _AdminOrdersViewState();
}

class _AdminOrdersViewState extends State<AdminOrdersView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Definimos los estados y los títulos para las pestañas
  final List<Map<String, String>> _tabs = [
    {'estado': 'pendiente', 'titulo': 'Pendientes'},
    {'estado': 'en preparacion', 'titulo': 'En Preparación'},
    {'estado': 'en camino', 'titulo': 'En Camino'},
    {'estado': 'entregado', 'titulo': 'Entregados'},
    {'estado': 'cancelado', 'titulo': 'Cancelados'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Forzamos un refresco en todas las pestañas
  void _refreshAllTabs() {
    setState(() {
      // Al cambiar el estado, los FutureBuilders se volverán a ejecutar
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Pedidos'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // Permite scroll si las pestañas no caben
          tabs: _tabs.map((tab) => Tab(text: tab['titulo']!)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) {
          return _OrderList(
            key: ValueKey(tab['estado']),
            estado: tab['estado']!,
            onRefresh: _refreshAllTabs,
          );
        }).toList(),
      ),
    );
  }
}

/// Widget que muestra la lista de pedidos para un estado específico y mantiene su estado.
class _OrderList extends StatefulWidget {
  final String estado;
  final VoidCallback onRefresh;

  const _OrderList({super.key, required this.estado, required this.onRefresh});

  @override
  State<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<_OrderList>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Pedido>> _pedidosFuture;

  @override
  void initState() {
    super.initState();
    _loadPedidos();
  }

  void _loadPedidos() {
    _pedidosFuture = Provider.of<DatabaseService>(context, listen: false)
        .getPedidosPorEstado(widget.estado);
  }

  void _refreshPedidos() {
    setState(() {
      _loadPedidos();
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Fecha desconocida';
    return DateFormat('dd MMM, hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Pedido>>(
      future: _pedidosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
              child: Text('Error al cargar pedidos: ${snapshot.error}'));
        }

        final pedidos = snapshot.data ?? [];

        if (pedidos.isEmpty) {
          return Center(
            child: Text('No hay pedidos en estado "${widget.estado}".'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            _refreshPedidos();
          },
          child: ListView.builder(
            itemCount: pedidos.length,
            itemBuilder: (context, index) {
              final pedido = pedidos[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined,
                      color: Colors.orange),
                  title: Text('Pedido #${pedido.idPedido}'),
                  subtitle:
                      Text('Recibido: ${_formatDate(pedido.fechaPedido)}'),
                  trailing: Text('\$${pedido.total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AdminOrderDetailScreen(idPedido: pedido.idPedido),
                        ));
                    if (result == true && mounted) widget.onRefresh();
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}