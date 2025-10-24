import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/session_state.dart';
import 'package:flutter_application_2/models/usuario.dart' show Usuario;
import 'package:flutter_application_2/services/database_service.dart';
import 'package:flutter_application_2/screen/chat_screen.dart';
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
    _tabController = TabController(length: 5, vsync: this);
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
            onPressed: () async {
              // Guardar dependencias del context ANTES del await
              final sessionController = context.read<SessionController>();
              final navigator = Navigator.of(context);

              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('userEmail');
              await prefs.remove('userPassword');
              
              sessionController.setGuest();
              navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pedidos Disponibles'),
            Tab(text: 'En curso'),
            Tab(text: 'Historial'),
            Tab(text: 'Chat'),
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
          DeliveryChatHubView(deliveryUser: widget.deliveryUser),
          DeliveryStatsView(deliveryUser: widget.deliveryUser),
        ],
      ),
    );
  }
}

/// Vista auxiliar para los chats
class DeliveryChatHubView extends StatelessWidget {
  final Usuario deliveryUser;
  const DeliveryChatHubView({super.key, required this.deliveryUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = <_ChatEntry>[
      const _ChatEntry(
        section: ChatSection.cliente,
        title: 'Chat con Cliente',
        description: 'Coordina entregas y resuelve dudas con tus clientes.',
        icon: Icons.person,
      ),
      const _ChatEntry(
        section: ChatSection.soporte,
        title: 'Chat con Soporte',
        description: 'Conecta con el equipo para reportar incidencias.',
        icon: Icons.support_agent,
      ),
    ];

    final firstName = deliveryUser.nombre.split(' ').first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Hola $firstName, gestiona tus conversaciones.', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        ...entries.map((entry) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withAlpha(25), // CORREGIDO
                          child: Icon(entry.icon, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(entry.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(entry.description, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(onPressed: () { /* Navegar a ChatScreen */ }, child: const Text('Abrir Chat')),
                    )
                  ],
                ),
              ),
            ),),
      ],
    );
  }
}

class _ChatEntry {
  final ChatSection section;
  final String title;
  final String description;
  final IconData icon;

  const _ChatEntry({
    required this.section,
    required this.title,
    required this.description,
    required this.icon,
  });
}

/// Panel de estadísticas del repartidor
class DeliveryStatsView extends StatefulWidget {
  final Usuario deliveryUser;
  const DeliveryStatsView({super.key, required this.deliveryUser});

  @override
  State<DeliveryStatsView> createState() => _DeliveryStatsViewState();
}

class _DeliveryStatsViewState extends State<DeliveryStatsView> {
  Future<_DeliveryStatsSnapshot>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<_DeliveryStatsSnapshot> _loadStats() async {
    final service = Provider.of<DatabaseService>(context, listen: false);
    final pedidos = await service.getPedidosPorDelivery(widget.deliveryUser.idUsuario);
    // Simulación de más datos para un ejemplo robusto
    final totalGenerado = pedidos.where((p) => p.estado == 'entregado').fold(0.0, (sum, p) => sum + p.total);
    return _DeliveryStatsSnapshot(
      pedidosActivos: pedidos.where((p) => p.estado == 'en_camino').length,
      pedidosCompletados: pedidos.where((p) => p.estado == 'entregado').length,
      totalGenerado: totalGenerado,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DeliveryStatsSnapshot>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _StatsError(onRetry: () => setState(() => _statsFuture = _loadStats()));
        }

        final stats = snapshot.data!;
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
                children: [
                  _StatTile(title: 'En Curso', value: stats.pedidosActivos.toString(), icon: Icons.delivery_dining, color: Colors.blue),
                  _StatTile(title: 'Completados Hoy', value: stats.pedidosCompletados.toString(), icon: Icons.check_circle, color: Colors.green),
                  _StatTile(title: 'Ganancia Hoy', value: NumberFormat.currency(locale: 'es_EC', symbol: '\$').format(stats.totalGenerado), icon: Icons.attach_money, color: Colors.teal),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeliveryStatsSnapshot {
  final int pedidosActivos;
  final int pedidosCompletados;
  final double totalGenerado;

  _DeliveryStatsSnapshot({
    required this.pedidosActivos,
    required this.pedidosCompletados,
    required this.totalGenerado,
  });
}

class _StatTile extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;

  const _StatTile({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(backgroundColor: color.withAlpha(30), child: Icon(icon, color: color)), // CORREGIDO
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(title),
          ],
        ),
      ),
    );
  }
}

class _StatsError extends StatelessWidget {
  final VoidCallback onRetry;
  const _StatsError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 50),
          const SizedBox(height: 16),
          const Text('No se pudieron cargar las estadísticas.'),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar'))
        ],
      ),
    );
  }
}
