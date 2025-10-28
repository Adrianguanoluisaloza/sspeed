import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:badges/badges.dart' as badges;

import 'package:flutter_application_2/models/ubicacion.dart';
import 'package:flutter_application_2/models/usuario.dart';
import 'package:flutter_application_2/services/database_service.dart';
import '../models/session_state.dart';
import '../routes/app_routes.dart';
import 'chat_screen.dart';

// Placeholder para la nueva pantalla
class AddLocationScreen extends StatelessWidget {
  const AddLocationScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Añadir Ubicación')), body: const Center(child: Text('Pantalla para añadir ubicación (WIP)')));
}

class ProfileScreen extends StatefulWidget {
  final Usuario usuario;
  const ProfileScreen({super.key, required this.usuario});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<List<Ubicacion>>? _ubicacionesFuture;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  void _loadLocations() {
    setState(() {
      _ubicacionesFuture = Provider.of<DatabaseService>(context, listen: false)
          .getUbicaciones(widget.usuario.idUsuario);
    });
  }

  Future<void> _handleLogout() async {
    final navigator = Navigator.of(context);
    final sessionController = context.read<SessionController>();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      sessionController.clearUser();
      navigator.pushNamedAndRemoveUntil(
        AppRoutes.login, // Lleva al login
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Cerrar Sesión',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildProfileHeader(theme, widget.usuario),
            const SizedBox(height: 24),
            Text('Gestión de la cuenta', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _buildMenuOption(context, icon: Icons.edit_outlined, color: Colors.blueAccent, title: 'Editar Perfil', subtitle: 'Actualiza tu nombre y correo', onTap: () => Navigator.of(context).pushNamed(AppRoutes.editProfile, arguments: widget.usuario)),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildMenuOption(context, icon: Icons.receipt_long_outlined, color: Colors.orangeAccent, title: 'Historial de Pedidos', subtitle: 'Consulta tus compras anteriores', onTap: () => Navigator.of(context).pushNamed(AppRoutes.orderHistory, arguments: widget.usuario)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Mis Ubicaciones', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<List<Ubicacion>>(
              future: _ubicacionesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return _buildErrorState('Error al cargar', 'No pudimos obtener tus ubicaciones.');
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState('Sin ubicaciones', 'Aún no has guardado ninguna dirección.', onRetry: _loadLocations);
                }
                final ubicaciones = snapshot.data!;
                return Column(
                  children: ubicaciones.map((ubicacion) => Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.place_outlined, color: Colors.green, size: 30),
                      title: Text(ubicacion.direccion ?? 'Dirección sin especificar', style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(ubicacion.descripcion ?? 'Sin descripción'),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () { /* Acción futura: editar o ver ubicación */ },
                    ),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: _buildSpeedDial(context),
    );
  }

  Widget _buildSpeedDial(BuildContext context) {
    return SpeedDial(
      icon: Icons.menu,      
      activeIcon: Icons.close,
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      overlayColor: Colors.black,
      overlayOpacity: 0.4,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.add_location_alt_outlined),
          label: 'Añadir Ubicación',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddLocationScreen())),
        ),
        SpeedDialChild(
          child: const Icon(Icons.smart_toy),
          label: 'CIA Bot',
          onTap: () {
            // Abrir el chat bot CIA Bot directamente desde el SpeedDial
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  initialSection: ChatSection.ciaBot,
                ),
              ),
            );
          },
        ),
      ],
    );
  }


  // Eliminado método duplicado _buildLoggedInScreen. Toda la lógica está en build().

  Widget _buildProfileHeader(ThemeData theme, Usuario usuario) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : '?', style: TextStyle(fontSize: 24, color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(usuario.nombre, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(usuario.correo, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    );
  }

  Widget _buildMenuOption(BuildContext context, {required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withAlpha(30), child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildErrorState(String title, String message) {
    return Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0), child: Column(children: [
      const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
    ])));
  }

  Widget _buildEmptyState(String title, String message, {required VoidCallback onRetry}) {
    return Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0), child: Column(children: [
      const Icon(Icons.map_outlined, size: 48, color: Colors.grey),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
      const SizedBox(height: 16),
      TextButton.icon(icon: const Icon(Icons.add), label: const Text('Añadir mi primera ubicación'), onPressed: onRetry)
    ])));
  }
}
