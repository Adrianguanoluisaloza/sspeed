import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/session_state.dart';
import 'package:flutter_application_2/models/usuario.dart' show Usuario;
import 'package:flutter_application_2/services/database_service.dart';
// import 'package:flutter_application_2/screen/chat_screen.dart'; // TODO: Arreglar la ruta o crear el archivo
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Se ajusta el length a 4 porque el Chat está deshabilitado temporalmente
    _tabController = TabController(length: 4, vsync: this);
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
        navigator.pushNamedAndRemoveUntil(
        AppRoutes.mainNavigator, 
        (route) => false, 
        arguments: Usuario.noAuth(),
        );
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
          )
        ],
        bottom: TabBar(
          isScrollable: true,
          controller: _tabController,
          tabs: const [
            Tab(text: 'Disponibles'),
            Tab(text: 'En Curso'),
            Tab(text: 'Historial'),
            // Tab(text: 'Chat'), // Deshabilitado temporalmente
            Tab(text: 'Estadísticas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DeliveryAvailableOrdersView(deliveryUser: widget.deliveryUser),
          DeliveryActiveOrdersView(deliveryUser: widget.deliveryUser),
          DeliveryHistoryOrdersView(deliveryUser: widget.deliveryUser),
          // DeliveryChatHubView(deliveryUser: widget.deliveryUser), // Deshabilitado
          DeliveryStatsView(deliveryUser: widget.deliveryUser),
        ],
      ),
    );
  }
}

// El DeliveryChatHubView se deja comentado por ahora
/*
class DeliveryChatHubView extends StatelessWidget {
  final Usuario deliveryUser;
  const DeliveryChatHubView({super.key, required this.deliveryUser});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('El chat está en desarrollo.'));
  }
}
*/

class DeliveryStatsView extends StatefulWidget {
  final Usuario deliveryUser;
  const DeliveryStatsView({super.key, required this.deliveryUser});

  @override
  State<DeliveryStatsView> createState() => _DeliveryStatsViewState();
}

class _DeliveryStatsViewState extends State<DeliveryStatsView> {
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<Map<String, dynamic>> _loadStats() {
    return Provider.of<DatabaseService>(context, listen: false)
        .getDeliveryStats(widget.deliveryUser.idUsuario);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar estadísticas: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No hay datos de estadísticas disponibles.'));
        }

        final stats = snapshot.data!;
        final totalGenerado = (stats['total_generado'] ?? 0.0).toDouble();
        final pedidosCompletados = (stats['pedidos_completados'] ?? 0).toInt();
        final promedioMinutos = (stats['tiempo_promedio_min'] ?? 0).toInt();

        return RefreshIndicator(
          onRefresh: () async => setState(() => _statsFuture = _loadStats()),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  _StatTile(title: 'Completados Hoy', value: pedidosCompletados.toString(), icon: Icons.check_circle, color: Colors.green),
                  _StatTile(title: 'Total Generado', value: NumberFormat.currency(locale: 'es_EC', symbol: '\$').format(totalGenerado), icon: Icons.attach_money, color: Colors.teal),
                  _StatTile(title: 'Tiempo Promedio', value: '$promedioMinutos min', icon: Icons.timer, color: Colors.blue),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;

  const _StatTile({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(backgroundColor: color.withAlpha(30), radius: 25, child: Icon(icon, color: color, size: 30)),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
