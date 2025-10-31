import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/usuario.dart';
import '../services/database_service.dart';

// -------------------------------------------------------------------
// VISTA DE LA PESTAÑA "ESTADÍSTICAS"
// -------------------------------------------------------------------

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
          return Center(
              child: Text('Error al cargar estadísticas: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text('No hay datos de estadísticas disponibles.'));
        }

        final stats = snapshot.data!;
        final totalGenerado = (stats['total_generado'] ?? 0.0).toDouble();
        final pedidosCompletados = (stats['pedidos_completados'] ?? 0).toInt();
        final promedioMinutos = (stats['tiempo_promedio_min'] ?? 0).toInt();

        return RefreshIndicator(
          onRefresh: () async => setState(() => _statsFuture = _loadStats()),
          child: GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _StatTile(
                  title: 'Completados Hoy',
                  value: pedidosCompletados.toString(),
                  icon: Icons.check_circle,
                  color: Colors.green),
              _StatTile(
                  title: 'Total Generado',
                  value: NumberFormat.currency(locale: 'es_EC', symbol: '\$')
                      .format(totalGenerado),
                  icon: Icons.attach_money,
                  color: Colors.teal),
              _StatTile(
                  title: 'Tiempo Promedio',
                  value: '$promedioMinutos min',
                  icon: Icons.timer,
                  color: Colors.blue),
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

  const _StatTile(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
                backgroundColor: color.withAlpha(30),
                radius: 25,
                child: Icon(icon, color: color, size: 30)),
            const SizedBox(height: 12),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
