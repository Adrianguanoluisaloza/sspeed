import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/usuario.dart' show Usuario;

import 'delivery_activearders_view.dart' show DeliveryActiveOrdersView;
import 'delivery_availableorders_view.dart' show DeliveryAvailableOrdersView;
import 'delivery_history_orders_view.dart' show DeliveryHistoryOrdersView;
import '../routes/app_routes.dart';

class DeliveryHomeScreen extends StatefulWidget {
  final Usuario deliveryUser;
  const DeliveryHomeScreen({super.key, required this.deliveryUser});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${widget.deliveryUser.nombre}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context)
                  .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pedidos Disponibles'),
            Tab(text: 'En curso'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Vista para pedidos disponibles
          DeliveryAvailableOrdersView(deliveryUser: widget.deliveryUser),
          // Vista para pedidos activos del repartidor
          DeliveryActiveOrdersView(deliveryUser: widget.deliveryUser),
          // Nueva vista para dar visibilidad al historial sin alterar la lógica existente.
          DeliveryHistoryOrdersView(deliveryUser: widget.deliveryUser),
        ],
      ),
    );
  }
}
