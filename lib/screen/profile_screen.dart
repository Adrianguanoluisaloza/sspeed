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
    // Solo carga ubicaciones si el usuario está autenticado
    if(widget.usuario.isAuthenticated) {
      _loadUbicaciones();
    }
  }

  void _loadUbicaciones() {
    _ubicacionesFuture = Provider.of<DatabaseService>(context, listen: false)
        .getUbicaciones(widget.usuario.idUsuario);
  }

  Future<void> _handleLogout() async {
    final navigator = Navigator.of(context);
    final session = context.read<SessionController>();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      session.clearUser(); // CORRECCIÓN: Se usa el método correcto
      navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si el usuario no está autenticado, muestra una pantalla para iniciar sesión.
    if (!widget.usuario.isAuthenticated) {
      return _buildLoggedOutScreen(context);
    }
    
    // Si está autenticado, muestra la pantalla normal del perfil.
    return _buildLoggedInScreen(context);
  }

  Widget _buildLoggedOutScreen(BuildContext context) {
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
              Icon(Icons.person_off_outlined, size: 96, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              const Text('Inicia sesión para ver tu perfil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Guarda direcciones, edita tu perfil y consulta tu historial de pedidos.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false),
                child: const Text('Iniciar Sesión o Registrarse'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedInScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Información del Usuario
            Card(
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepOrange,
                  child: Text(
                    widget.usuario.nombre.isNotEmpty ? widget.usuario.nombre[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(widget.usuario.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Correo: ${widget.usuario.correo}'),
              ),
            ),
            const SizedBox(height: 20),

            // Acciones de la cuenta
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.deepOrange),
                    title: const Text('Editar Perfil'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.editProfile, arguments: widget.usuario),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.receipt_long, color: Colors.deepOrange),
                    title: const Text('Historial de Pedidos'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.orderHistory, arguments: widget.usuario),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Sección de Ubicaciones
            Text('Mis Ubicaciones Guardadas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            FutureBuilder<List<Ubicacion>>(
              future: _ubicacionesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text('Error al cargar ubicaciones: ${snapshot.error}')));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Padding(padding: EdgeInsets.all(20.0), child: Text('No has guardado ninguna ubicación.')),
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
                      margin: const EdgeInsets.only(top: 8.0),
                      child: ListTile(
                        leading: const Icon(Icons.place, color: Colors.green),
                        title: Text(ubicacion.direccion ?? 'Dirección sin especificar'),
                        subtitle: Text('Lat: ${ubicacion.latitud.toStringAsFixed(4)}, Lon: ${ubicacion.longitud.toStringAsFixed(4)}'),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 30),

            // Botón de Cerrar Sesión
            Center(
              child: ElevatedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar Sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
