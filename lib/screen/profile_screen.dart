import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_2/models/ubicacion.dart';
import 'package:flutter_application_2/models/usuario.dart';
import 'package:flutter_application_2/services/database_service.dart';
import '../models/session_state.dart';
import '../routes/app_routes.dart';

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
    if (widget.usuario.isAuthenticated) {
      _ubicacionesFuture = Provider.of<DatabaseService>(context, listen: false)
          .getUbicaciones(widget.usuario.idUsuario);
    }
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
    if (!widget.usuario.isAuthenticated) {
      return _buildLoggedOutScreen(context);
    }
    return _buildLoggedInScreen(context);
  }

  // --- PANTALLA PARA INVITADOS (VERSIÓN MEJORADA) ---
  Widget _buildLoggedOutScreen(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_off_outlined, size: 80, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Text('Tu perfil te está esperando', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text('Inicia sesión para guardar tus direcciones, editar datos y consultar tu historial de pedidos.', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600])),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
                label: const Text('Iniciar Sesión o Registrarse'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- PANTALLA PARA USUARIOS CON SESIÓN (VERSIÓN MEJORADA) ---
  Widget _buildLoggedInScreen(BuildContext context) {
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
                  return _buildEmptyState('Sin ubicaciones', 'Aún no has guardado ninguna dirección. ¡Añade una para agilizar tus pedidos!');
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
    );
  }

  // --- WIDGETS AUXILIARES PARA UN CÓDIGO MÁS LIMPIO ---

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
      leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
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

  Widget _buildEmptyState(String title, String message) {
    return Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0), child: Column(children: [
      const Icon(Icons.map_outlined, size: 48, color: Colors.grey),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
    ])));
  }
}
