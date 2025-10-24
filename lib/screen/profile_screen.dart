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
  Future<List<Ubicacion>>? _ubicacionesFuture;

  bool get _isGuest => widget.usuario.isGuest;

  @override
  void initState() {
    super.initState();
    if (!_isGuest) {
      _ubicacionesFuture = Provider.of<DatabaseService>(context, listen: false)
          .getUbicaciones(widget.usuario.idUsuario);
    }
  }

  Future<void> _handleLogout() async {
    final navigator = Navigator.of(context);
    final session = context.read<SessionController>();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userEmail');
    await prefs.remove('userPassword');

    if (!mounted) return;
    context.read<SessionController>().setGuest();
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isGuest) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mi Perfil'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline,
                    size: 96, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                const Text(
                  'Explora más iniciando sesión',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Guarda direcciones, consulta tu historial de pedidos y personaliza tu experiencia.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.login),
                  child: const Text('Iniciar sesión'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.register),
                  child: const Text('Crear una cuenta'),
                )
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil y Ubicaciones'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Información del Usuario
            Card(
              elevation: 4,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepOrange,
                  child: Text(
                    widget.usuario.nombre.isNotEmpty
                        ? widget.usuario.nombre[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(widget.usuario.nombre),
                subtitle: Text(
                    'Correo: ${widget.usuario.correo}\nRol: ${widget.usuario.rol}'),
              ),
            ),

            const SizedBox(height: 20),

            // --- NUEVO BOTÓN: HISTORIAL DE PEDIDOS ---
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long, color: Colors.deepOrange),
                title: const Text('Historial de Pedidos'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.orderHistory,
                    arguments: widget.usuario,
                  );
                },
              ),
            ),
            // ------------------------------------------

            const SizedBox(height: 20),

            // Sección de Ubicaciones
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mis Ubicaciones Guardadas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_location_alt,
                      color: Colors.deepOrange),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                          Text('Añadir Ubicación (Función en desarrollo)')),
                    );
                  },
                ),
              ],
            ),
            const Divider(),

            // Lista de ubicaciones
            FutureBuilder<List<Ubicacion>>(
              future: _ubicacionesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text(
                          'Error al cargar ubicaciones: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text('No has guardado ninguna ubicación.'),
                    ),
                  );
                }

                final ubicaciones = snapshot.data!;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ubicaciones.length,
                  itemBuilder: (context, index) {
                    final ubicacion = ubicaciones[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: ListTile(
                        leading:
                        const Icon(Icons.place, color: Colors.green),
                        title: Text(ubicacion.direccion ?? 'Dirección sin especificar'),
                        subtitle: Text(
                            'Lat: ${ubicacion.latitud.toStringAsFixed(4)}, Lon: ${ubicacion.longitud.toStringAsFixed(4)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () {
                            // TODO: lógica de eliminación
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 30),

            // --- BOTÓN DE CERRAR SESIÓN ---
            Center(
              child: ElevatedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar Sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
              ),
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

