import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import "package:badges/badges.dart" as badges;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session_state.dart';
import '../models/usuario.dart';
import '../routes/app_routes.dart';

// Importa las otras vistas que ya tenías separadas

import 'delivery_activearders_view.dart' show DeliveryActiveOrdersView;
import 'delivery_availableorders_view.dart' show DeliveryAvailableOrdersView;
import 'delivery_history_orders_view.dart';
import 'delivery_chat_hub_view.dart';
import 'delivery_stats_view.dart';

// -------------------------------------------------------------------
// VISTA PRINCIPAL (HOME SCREEN)
// -------------------------------------------------------------------

class DeliveryHomeScreen extends StatefulWidget {
  final Usuario deliveryUser;
  const DeliveryHomeScreen({super.key, required this.deliveryUser});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _availableOrdersCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  void _onAvailableOrdersChanged(int count) {
    if (mounted && _availableOrdersCount != count) {
      setState(() => _availableOrdersCount = count);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final navigator = Navigator.of(context);
    final sessionController = context.read<SessionController>();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      sessionController.clearUser();
      navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${widget.deliveryUser.nombre}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Cerrar Sesión',
          ),
        ],
        bottom: TabBar(
          isScrollable: true,
          controller: _tabController,
          tabs: <Widget>[
            _buildTabWithBadge(
              text: 'Disponibles',
              icon: Icons.list_alt,
              count: _availableOrdersCount,
            ),
            const Tab(text: 'En Curso', icon: Icon(Icons.delivery_dining)),
            const Tab(text: 'Historial', icon: Icon(Icons.history)),
            const Tab(text: 'Chat', icon: Icon(Icons.chat)),
            const Tab(text: 'Estadísticas', icon: Icon(Icons.bar_chart)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DeliveryAvailableOrdersView(
            deliveryUser: widget.deliveryUser,
            onOrderCountChanged: _onAvailableOrdersChanged,
          ),
          DeliveryActiveOrdersView(deliveryUser: widget.deliveryUser),
          DeliveryHistoryOrdersView(deliveryUser: widget.deliveryUser),
          // Las vistas que estaban en el mismo archivo
          DeliveryChatHubView(deliveryUser: widget.deliveryUser),
          DeliveryStatsView(deliveryUser: widget.deliveryUser),
        ],
      ),
    );
  }

  Widget _buildTabWithBadge(
      {required String text, required IconData icon, required int count}) {
    return Tab(
      child: badges.Badge(
        showBadge: count > 0,
        badgeContent: Text(
          count.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
        position: badges.BadgePosition.topEnd(top: -12, end: -20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(text),
          ],
        ),
      ),
    );
  }
}
