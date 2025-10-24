import 'dart:ui';

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
  late Future<List<Ubicacion>> _ubicacionesFuture;

  @override
  void initState() {
    super.initState();
    _loadUbicaciones();
  }
  
  void _loadUbicaciones() {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    _ubicacionesFuture = dbService.getUbicaciones(widget.usuario.idUsuario);
  }

  Future<void> _refreshData() async {
    setState(() {
      _loadUbicaciones();
    });
  }

  Future<void> _handleLogout() async {
    final navigator = Navigator.of(context);
    final session = context.read<SessionController>();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    session.setGuest();
    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = widget.usuario.nombre.isNotEmpty ? widget.usuario.nombre[0].toUpperCase() : '?';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              expandedHeight: 220.0,
              backgroundColor: Colors.deepOrange,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(widget.usuario.nombre, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                background: _UserInfoHeader(initial: initial, usuario: widget.usuario),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                const _SectionTitle(title: 'Mis Ubicaciones'),
                _buildUbicaciones(theme),
                const SizedBox(height: 24),
                _buildActionButtons(context),
                const SizedBox(height: 40),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUbicaciones(ThemeData theme) {
    return FutureBuilder<List<Ubicacion>>(
      future: _ubicacionesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return _EmptyState(icon: Icons.cloud_off, message: 'Error al cargar ubicaciones', onActionPressed: _refreshData, actionText: 'Reintentar');
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _EmptyState(icon: Icons.add_location, message: 'No tienes direcciones guardadas', onActionPressed: () {}, actionText: 'Añadir Dirección');
        }
        final ubicaciones = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: ubicaciones.map((ubicacion) => _UbicacionTile(ubicacion: ubicacion)).toList(),
          ),
        );
      },
    );
  }
  
  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          _ActionTile(icon: Icons.edit, title: 'Editar Perfil', onTap: () => Navigator.of(context).pushNamed(AppRoutes.editProfile, arguments: widget.usuario)),
          const Divider(),
          _ActionTile(icon: Icons.receipt_long, title: 'Historial de Pedidos', onTap: () => Navigator.of(context).pushNamed(AppRoutes.orderHistory, arguments: widget.usuario)),
          const Divider(),
          _ActionTile(icon: Icons.logout, title: 'Cerrar Sesión', color: Colors.red.shade700, onTap: _handleLogout),
        ],
      ),
    );
  }
}

class _UserInfoHeader extends StatelessWidget {
  final String initial;
  final Usuario usuario;
  const _UserInfoHeader({required this.initial, required this.usuario});

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      Container(color: Colors.deepOrange),
      ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), child: Container(color: Colors.black.withAlpha(50)))),
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircleAvatar(radius: 40, backgroundColor: Colors.white, child: Text(initial, style: const TextStyle(fontSize: 32, color: Colors.deepOrange, fontWeight: FontWeight.bold))),
        const SizedBox(height: 12),
        Text(usuario.correo, style: const TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(blurRadius: 2, color: Colors.black54)]))
      ]),
    ]);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class _UbicacionTile extends StatelessWidget {
  final Ubicacion ubicacion;
  const _UbicacionTile({required this.ubicacion});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.location_on_outlined)),
        title: Text(ubicacion.direccion ?? 'Ubicación'),
        subtitle: Text('Lat: ${ubicacion.latitud.toStringAsFixed(4)}, Lon: ${ubicacion.longitud.toStringAsFixed(4)}', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: () { /* TODO: Navegar a pantalla de detalle/editar ubicación */ },
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final titleColor = color ?? Theme.of(context).textTheme.bodyLarge?.color;
    final iconColor = color ?? Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionText;
  final VoidCallback onActionPressed;
  const _EmptyState({required this.icon, required this.message, required this.actionText, required this.onActionPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Icon(icon, size: 50, color: Colors.grey.shade500),
        const SizedBox(height: 16),
        Text(message, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: onActionPressed, child: Text(actionText)),
      ]),
    );
  }
}
