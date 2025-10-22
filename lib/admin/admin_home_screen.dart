import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/pedido.dart';
import 'package:flutter_application_2/models/usuario.dart';
import 'package:flutter_application_2/screen/order_history_screen.dart'; // Reutiliza OrderCard
import 'package:flutter_application_2/services/database_service.dart';
import 'package:provider/provider.dart';
import 'admin_order_detail_screen.dart' show AdminOrderDetailScreen;
import 'admin_products_scree.dart' show AdminProductsScreen;
import 'package:intl/intl.dart'; // Para formatear moneda


class AdminHomeScreen extends StatefulWidget {
  final Usuario adminUser;
  const AdminHomeScreen({super.key, required this.adminUser});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  // --- ESTADOS PARA LOS FUTURES ---
  late Future<List<Pedido>> _pedidosPendientesFuture;
  late Future<Map<String, dynamic>> _statsFuture; // <-- NUEVO FUTURE PARA STATS

  // Para formatear el dinero
  final currencyFormatter = NumberFormat.currency(locale: 'es_EC', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    _pedidosPendientesFuture = dbService.getPedidosPorEstado('pendiente');
    _statsFuture = dbService.getAdminStats();
  }

  void _refreshAll() {
    setState(() {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh), // <-- BOTÓN DE REFRESCO
            onPressed: _refreshAll,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          // --- SECCIÓN 1: DASHBOARD DE ESTADÍSTICAS ---
          _buildStatsSection(),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // --- SECCIÓN 2: MENÚ DE GESTIÓN ---
          _buildManagementMenu(),
        ],
      ),
    );
  }

  /// Widget para el Dashboard de Estadísticas
  Widget _buildStatsSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Un shimmer o loading simple para las tarjetas
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!['success'] != true) {
          return const Center(child: Text('Error al cargar estadísticas'));
        }

        final stats = snapshot.data!;
        final double ventasHoy = stats['ventas_hoy']?.toDouble() ?? 0.0;
        final int pedidosPendientes = stats['pedidos_pendientes']?.toInt() ?? 0;
        final int nuevosClientes = stats['nuevos_clientes']?.toInt() ?? 0;

        // Grid para las tarjetas de estadísticas
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5, // Hace las tarjetas un poco más anchas que altas
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _StatCard(
              title: 'Ventas de Hoy',
              value: currencyFormatter.format(ventasHoy), // Formatea como $0.00
              icon: Icons.monetization_on,
              color: Colors.green,
            ),
            _StatCard(
              title: 'Pendientes',
              value: pedidosPendientes.toString(),
              icon: Icons.pending_actions,
              color: Colors.orange,
            ),
            _StatCard(
              title: 'Clientes Hoy',
              value: nuevosClientes.toString(),
              icon: Icons.person_add,
              color: Colors.blue,
            ),
            _StatCard(
              title: 'Próximamente',
              value: '...',
              icon: Icons.bar_chart,
              color: Colors.grey,
            ),
          ],
        );
      },
    );
  }

  /// Widget para los botones del menú de gestión
  Widget _buildManagementMenu() {
    return Column(
      children: [
        // --- Opción: Gestión de productos ---
        Card(
          child: ListTile(
            leading: const Icon(Icons.fastfood, color: Colors.blue),
            title: const Text('Gestionar Productos'),
            subtitle: const Text('Agregar, editar o eliminar productos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminProductsScreen()),
              );
            },
          ),
        ),

        // --- Opción: Pedidos pendientes ---
        Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.orange),
            title: const Text('Pedidos Pendientes'),
            subtitle: const Text('Ver y gestionar pedidos en espera'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _buildPedidosPendientesScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Widget que construye la pantalla de "Pedidos Pendientes"
  Widget _buildPedidosPendientesScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text("Pedidos Pendientes")),
      body: FutureBuilder<List<Pedido>>(
        future: _pedidosPendientesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text("No hay pedidos pendientes.", style: TextStyle(fontSize: 18)));
          }

          final pedidos = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _pedidosPendientesFuture = Provider.of<DatabaseService>(context, listen: false)
                    .getPedidosPorEstado('pendiente');
              });
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: pedidos.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AdminOrderDetailScreen(idPedido: pedidos[index].idPedido),
                      ),
                    );
                    if (result == true) _refreshAll(); // Refresca todo
                  },
                  child: OrderCard(pedido: pedidos[index]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Un widget reutilizable para las tarjetas de estadísticas
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 30, color: color),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
