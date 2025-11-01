import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session_state.dart';
import '../models/usuario.dart';
import '../routes/app_routes.dart';
import '../services/database_service.dart';
import '../admin/business_products_view.dart';

class NegocioHomeScreen extends StatefulWidget {
  final Usuario negocioUser;
  const NegocioHomeScreen({super.key, required this.negocioUser});

  @override
  State<NegocioHomeScreen> createState() => _NegocioHomeScreenState();
}

class _NegocioHomeScreenState extends State<NegocioHomeScreen> {
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    final db = Provider.of<DatabaseService>(context, listen: false);
    _statsFuture = db
        .getNegocioDeUsuario(widget.negocioUser.idUsuario)
        .then((negocio) async {
      if (negocio == null || (negocio.idNegocio == 0)) {
        return <String, dynamic>{};
      }
      return await db.getNegocioStats(negocio.idNegocio);
    });
  }

  Future<void> _handleLogout() async {
    final navigator = Navigator.of(context);
    final session = context.read<SessionController>();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      session.clearUser();
      navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Negocio'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() => _loadStats())),
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleLogout,
              tooltip: 'Cerrar Sesion'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen del Dia',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<Map<String, dynamic>>(
              future: _statsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text(
                          'Error al cargar estadisticas: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _StatsGridLoading();
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('No hay estadisticas disponibles.'));
                }
                final stats = snapshot.data!;
                return _StatsGrid(stats: stats);
              },
            ),
            const SizedBox(height: 24),
            Text('Gestion',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _MenuActionCard(
              title: 'Mis Productos (Negocio)',
              subtitle: 'Gestiona el catalogo de tu negocio',
              icon: Icons.store_mall_directory_outlined,
              color: Colors.teal,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    BusinessProductsView(negocioUser: widget.negocioUser),
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
            title: 'Ingresos Totales',
            value: '\$${(stats['ingresos_totales'] ?? 0).toStringAsFixed(2)}',
            icon: Icons.attach_money,
            color: Colors.green),
        _StatCard(
            title: 'Pedidos Completados',
            value: (stats['pedidos_completados'] ?? 0).toString(),
            icon: Icons.check_circle_outline,
            color: Colors.blue),
        _StatCard(
            title: 'Productos Vendidos',
            value: (stats['productos_vendidos'] ?? 0).toString(),
            icon: Icons.list_alt,
            color: Colors.purple),
        _StatCard(
            title: 'Productos Activos',
            value: (stats['total_productos'] ?? 0).toString(),
            icon: Icons.list_alt,
            color: Colors.purple),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;

  const _StatCard(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
                backgroundColor: color.withAlpha(51),
                child: Icon(icon, color: color)),
            const Spacer(),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class _StatsGridLoading extends StatelessWidget {
  const _StatsGridLoading();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children:
          List.generate(4, (index) => const Card(child: SizedBox.expand())),
    );
  }
}

class _MenuActionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuActionCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        leading: CircleAvatar(
            backgroundColor: color.withAlpha(26),
            child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}