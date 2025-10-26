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

  // Lógica de Logout Correcta y Unificada
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
          // Se usa el método _handleLogout del State
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

class DeliveryChatHubView extends StatelessWidget {
  final Usuario deliveryUser;
  const DeliveryChatHubView({super.key, required this.deliveryUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // CORRECCIÓN: Se elimina `const` para solucionar el error de tipo
    final entries = <_ChatEntry>[
      _ChatEntry(
        section: ChatSection.cliente,
        title: 'Chat con Cliente',
        description:
            'Coordina entregas y resuelve dudas rápidas con tus clientes activos.',
        icon: Icons.person,
      ),
      _ChatEntry(
        section: ChatSection.soporte,
        title: 'Chat con Soporte',
        description:
            'Conecta con el equipo de soporte para reportar incidencias en ruta.',
        icon: Icons.support_agent,
      ),
      _ChatEntry(
        section: ChatSection.historial,
        title: 'Historial',
        description:
            'Revisa conversaciones recientes y mantén un registro de tus seguimientos.',
        icon: Icons.history,
      ),
    ];

    final firstName = deliveryUser.nombre.split(' ').first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Gestiona tus conversaciones, $firstName',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withAlpha(30),
                          child: Icon(entry.icon, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      entry.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => ChatScreen(initialSection: entry.section)),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Abrir chat'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
