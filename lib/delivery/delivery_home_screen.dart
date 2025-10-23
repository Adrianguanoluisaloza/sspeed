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
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('userEmail');
              await prefs.remove('userPassword');
              if (!mounted) return;
              context.read<SessionController>().setGuest();
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
            Tab(text: 'Chat'),
            Tab(text: 'Estadísticas'),
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
          // Accesos rápidos al centro de mensajería con animaciones suaves.
          DeliveryChatHubView(deliveryUser: widget.deliveryUser),
          // Panel ligero con métricas del repartidor.
          DeliveryStatsView(deliveryUser: widget.deliveryUser),
        ],
      ),
    );
  }
}

/// Vista auxiliar que presenta accesos animados hacia cada tipo de chat.
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
        description:
            'Coordina entregas y resuelve dudas rápidas con tus clientes activos.',
        icon: Icons.person,
      ),
      const _ChatEntry(
        section: ChatSection.soporte,
        title: 'Chat con Soporte',
        description:
            'Conecta con el equipo de soporte para reportar incidencias en ruta.',
        icon: Icons.support_agent,
      ),
      const _ChatEntry(
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
        const SizedBox(height: 4),
        Text(
          'Selecciona una pestaña para continuar chateando sin perder el estilo original.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
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
                              PageRouteBuilder(
                                transitionDuration:
                                    const Duration(milliseconds: 280),
                                pageBuilder: (_, animation, __) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ChatScreen(
                                      initialSection: entry.section,
                                    ),
                                  );
                                },
                              ),
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

/// Pequeño contenedor de datos para mantener organizado el resumen de métricas.
class _DeliveryStatsSnapshot {
  final int pedidosDisponibles;
  final int pedidosActivos;
  final int pedidosCompletados;
  final double totalGenerado;
  final Duration? promedioEntrega;

  const _DeliveryStatsSnapshot({
    required this.pedidosDisponibles,
    required this.pedidosActivos,
    required this.pedidosCompletados,
    required this.totalGenerado,
    required this.promedioEntrega,
  });
}

/// Panel ligero que sintetiza el rendimiento reciente del repartidor.
class DeliveryStatsView extends StatefulWidget {
  final Usuario deliveryUser;
  const DeliveryStatsView({super.key, required this.deliveryUser});

  @override
  State<DeliveryStatsView> createState() => _DeliveryStatsViewState();
}

class _DeliveryStatsViewState extends State<DeliveryStatsView> {
  late Future<_DeliveryStatsSnapshot> _statsFuture;
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(locale: 'es_EC', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<_DeliveryStatsSnapshot> _loadStats() async {
    final service = Provider.of<DatabaseService>(context, listen: false);
    final pedidosAsignados =
        await service.getPedidosPorDelivery(widget.deliveryUser.idUsuario);
    final pedidosDisponibles = await service.getPedidosDisponibles();

    final completados = pedidosAsignados.where((pedido) {
      final estado = pedido.estado.toLowerCase();
      return estado.contains('entregado') || estado.contains('completado');
    }).toList();

    final activos = pedidosAsignados.where((pedido) {
      final estado = pedido.estado.toLowerCase();
      final esFinalizado =
          estado.contains('entregado') || estado.contains('cancelado');
      return !esFinalizado;
    }).toList();

    final totalGenerado =
        completados.fold<double>(0, (sum, pedido) => sum + pedido.total);

    final duraciones = completados
        .where((pedido) => pedido.fechaEntrega != null)
        .map((pedido) => pedido.fechaEntrega!.difference(pedido.fechaPedido))
        .where((duracion) => !duracion.isNegative)
        .toList();

    Duration? promedioEntrega;
    if (duraciones.isNotEmpty) {
      final totalMinutos =
          duraciones.fold<int>(0, (sum, duracion) => sum + duracion.inMinutes);
      if (totalMinutos > 0) {
        promedioEntrega =
            Duration(minutes: (totalMinutos / duraciones.length).round());
      }
    }

    return _DeliveryStatsSnapshot(
      pedidosDisponibles: pedidosDisponibles.length,
      pedidosActivos: activos.length,
      pedidosCompletados: completados.length,
      totalGenerado: totalGenerado,
      promedioEntrega: promedioEntrega,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _statsFuture = _loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DeliveryStatsSnapshot>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _StatsError(onRetry: _refresh);
        }
        final data = snapshot.data;
        if (data == null) {
          return _StatsError(onRetry: _refresh);
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Resumen de tus entregas',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mantén visibilidad de tu carga de trabajo y tiempos promedio sin modificar el estilo original.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _StatTile(
                    title: 'Disponibles',
                    value: data.pedidosDisponibles.toString(),
                    icon: Icons.assignment,
                    color: Colors.deepOrange,
                  ),
                  _StatTile(
                    title: 'En curso',
                    value: data.pedidosActivos.toString(),
                    icon: Icons.delivery_dining,
                    color: Colors.indigo,
                  ),
                  _StatTile(
                    title: 'Completados',
                    value: data.pedidosCompletados.toString(),
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                  _StatTile(
                    title: 'Total generado',
                    value: _currencyFormatter.format(data.totalGenerado),
                    icon: Icons.attach_money,
                    color: Colors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.timer, color: Colors.orangeAccent),
                  title: const Text('Tiempo promedio de entrega'),
                  subtitle: Text(_formatDuration(data.promedioEntrega)),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.insights, color: Colors.purple),
                  title: const Text('Sugerencia'),
                  subtitle: Text(
                    data.pedidosActivos > 3
                        ? 'Administra tus rutas y prioriza las entregas próximas para evitar retrasos.'
                        : '¡Buen ritmo! Puedes aceptar más pedidos si lo deseas.',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'Sin datos suficientes';
    if (duration.inHours > 0) {
      final horas = duration.inHours;
      final minutosRestantes = duration.inMinutes.remainder(60);
      return '${horas}h ${minutosRestantes}min';
    }
    return '${duration.inMinutes} minutos';
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsError extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _StatsError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              'No pudimos cargar tus métricas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Revisa tu conexión o desliza hacia abajo para intentarlo nuevamente.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
