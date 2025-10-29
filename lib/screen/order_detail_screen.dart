import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/session_state.dart';
import '../models/pedido_detalle.dart';
import '../models/pedido.dart';
import '../services/database_service.dart';
import '../routes/app_routes.dart';
import 'chat_screen.dart';
import '../models/usuario.dart';

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
    _loadOrderDetails();
  }

  void _loadOrderDetails() {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    setState(() {
      _detailsFuture = dbService.getPedidoDetalle(widget.idPedido);
    });
  }

  Future<void> _refresh() async {
    _loadOrderDetails();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PedidoDetalle?>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        Widget body;
        double? total;

        if (snapshot.connectionState == ConnectionState.waiting) {
          body = const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          body = _buildErrorView(snapshot.error);
        } else if (!snapshot.hasData || snapshot.data == null) {
          body = const Center(child: Text('Pedido no encontrado.'));
        } else {
          final pedidoDetalle = snapshot.data!;
          total = pedidoDetalle.pedido.total;
          body = _buildBodyContent(pedidoDetalle);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalle del Pedido'),
          ),
          body: body,
          bottomNavigationBar: total != null ? _buildTotalSummary(total) : null,
        );
      },
    );
  }

  Widget _buildBodyContent(PedidoDetalle pedidoDetalle) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHeaderCard(pedidoDetalle.pedido),
          const SizedBox(height: 24),
          _buildSectionTitle('Seguimiento'),
          _buildTimelineCard(pedidoDetalle.pedido.estado),
          const SizedBox(height: 12),
          if (pedidoDetalle.pedido.idDelivery != null) ...[
            _buildChatCard(pedidoDetalle.pedido),
            const SizedBox(height: 12),
          ],
          _buildTrackingMapCard(pedidoDetalle.pedido),
          const SizedBox(height: 24),
          _buildSectionTitle('Productos'),
          _buildProductsListCard(pedidoDetalle.detalles),
        ],
      ),
    );
  }

  Widget _buildTotalSummary(double total) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16).copyWith(bottom: 24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(13),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Total Pagado:',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text('\$${total.toStringAsFixed(2)}',
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold, color: theme.primaryColor)),
      ]),
    );
  }

  Widget _buildHeaderCard(Pedido pedido) {
    final formattedDate =
        DateFormat('dd MMM yyyy, hh:mm a', 'es_MX').format(pedido.fechaPedido);
    final theme = Theme.of(context);
    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('PEDIDO #${pedido.idPedido}',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              _StatusChip(status: pedido.estado),
            ]),
            const SizedBox(height: 8),
            Text(formattedDate, style: TextStyle(color: Colors.grey.shade600)),
            const Divider(height: 24),
            Row(children: [
              Icon(Icons.location_on_outlined,
                  color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 8),
              // CORRECCIÓN: Se elimina el operador '??' innecesario.
              Expanded(child: Text(pedido.direccionEntrega)),
            ]),
          ]),
        ));
  }

  Widget _buildTimelineCard(String estadoActual) {
    final estados = {
      'pendiente': 'Pendiente',
      'en preparacion': 'Preparando',
      'en camino': 'En Camino',
      'entregado': 'Entregado',
    };
    int currentStep = estados.keys.toList().indexOf(estadoActual.toLowerCase());
    if (currentStep == -1) currentStep = 0;
    return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(estados.length, (index) {
                return _TimelineStep(
                    title: estados.values.elementAt(index),
                    isDone: index <= currentStep);
              })),
        ));
  }

  Widget _buildChatCard(Pedido pedido) {
    final Usuario? currentUser =
        Provider.of<SessionController>(context, listen: false).usuario;

    // No mostrar el botón si no podemos identificar al usuario actual.
    if (currentUser == null || !currentUser.isAuthenticated) {
      return const SizedBox.shrink();
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                currentUser: currentUser,
                idConversacion: pedido
                    .idPedido, // Usamos el ID del pedido como ID de conversación
                initialSection: ChatSection
                    .cliente, // La sección puede ser para dar un título
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
                child: Text('Chatear con el repartidor',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold))),
            const Icon(Icons.chat_bubble_outline, color: Colors.grey),
          ]),
        ),
      ),
    );
  }

  Widget _buildTrackingMapCard(Pedido pedido) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(
            AppRoutes.trackingSimulation,
            arguments: pedido.idPedido),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              height: 150,
              decoration: BoxDecoration(color: Colors.grey.shade300),
              child: Center(
                child: Icon(Icons.map_outlined,
                    size: 60, color: Colors.grey.shade600),
              )),
          Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Seguimiento en Vivo',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Toca para ver la ubicación del repartidor',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 14)),
                        ])),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.grey, size: 16),
                  ])),
        ]),
      ),
    );
  }

  // CORRECCIÓN: Se usa el tipo de dato correcto 'ProductoDetalle'.
  Widget _buildProductsListCard(List<ProductoDetalle> detalles) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: detalles.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final item = detalles[index];
          return ListTile(
            leading: SizedBox(
                width: 56,
                height: 56,
                child: _OrderItemImage(imageUrl: item.imagenUrl)),
            title: Text(item.nombreProducto,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                'Cant: ${item.cantidad} x \$${item.precioUnitario.toStringAsFixed(2)}'),
            trailing: Text('\$${item.subtotal.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0, top: 8.0),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildErrorView(Object? error) {
    debugPrint('Error en OrderDetailScreen: $error');
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(24.0),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline,
                  size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text('No se pudieron cargar los detalles del pedido.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                  label: const Text('Reintentar')),
            ])));
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
      case 'en preparacion':
        color = Colors.cyan;
        label = 'Preparando';
        icon = Icons.restaurant_menu_outlined;
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

class _TimelineStep extends StatelessWidget {
  final String title;
  final bool isDone;
  const _TimelineStep({required this.title, required this.isDone});

  @override
  Widget build(BuildContext context) {
    final color =
        isDone ? Theme.of(context).primaryColor : Colors.grey.shade400;
    return Column(children: [
      Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked,
          color: color),
      const SizedBox(height: 4),
      Text(title,
          style: TextStyle(
              color: color,
              fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
              fontSize: 12)),
    ]);
  }
}

class _OrderItemImage extends StatelessWidget {
  final String? imageUrl;
  const _OrderItemImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return Container(
        decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8.0)),
        child: const Center(
            child: Icon(Icons.fastfood_outlined, color: Colors.grey, size: 30)),
      );
    }
    return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8.0)),
            child: const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: Colors.grey, size: 30)),
          ),
        ));
  }
}
