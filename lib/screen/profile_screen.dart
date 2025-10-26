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

  // CORRECCIÓN DEFINITIVA: Lógica de logout segura que navega a la pantalla principal.
  Future<void> _handleLogout() async {
    final navigator = Navigator.of(context);
    final sessionController = context.read<SessionController>();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
        sessionController.clearUser();
        navigator.pushNamedAndRemoveUntil(
        AppRoutes.mainNavigator, // Navega a la pantalla de inicio
        (route) => false, 
        arguments: Usuario.noAuth(), // Pasa un usuario no autenticado
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

  // Pantalla para usuarios que NO han iniciado sesión
  Widget _buildLoggedOutScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_outlined, size: 96, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              const Text('Inicia sesión para ver tu perfil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Guarda direcciones, edita tus datos y consulta tu historial de pedidos.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
                child: const Text('Iniciar Sesión o Registrarse'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Pantalla para usuarios que SÍ han iniciado sesión
  Widget _buildLoggedInScreen(BuildContext context) {
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
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(widget.usuario.nombre.isNotEmpty ? widget.usuario.nombre[0] : '?')),
                title: Text(widget.usuario.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(widget.usuario.correo),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                    title: const Text('Editar Perfil'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.editProfile, arguments: widget.usuario),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined, color: Colors.orangeAccent),
                    title: const Text('Historial de Pedidos'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.orderHistory, arguments: widget.usuario),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text('Mis Ubicaciones', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            FutureBuilder<List<Ubicacion>>(
              future: _ubicacionesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error al cargar ubicaciones: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No tienes ubicaciones guardadas.'));
                }
                final ubicaciones = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ubicaciones.length,
                  itemBuilder: (context, index) {
                    final ubicacion = ubicaciones[index];
                    return Card(
                      margin: const EdgeInsets.only(top: 8.0),
                      child: ListTile(
                        leading: const Icon(Icons.place_outlined, color: Colors.green),
                        title: Text(ubicacion.direccion ?? 'Dirección sin especificar'),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
