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
              Icon(Icons.person_off_outlined, size: 96, color: Theme
                  .of(context)
                  .colorScheme
                  .primary),
              const SizedBox(height: 16),
              const Text('Inicia sesión para ver tu perfil',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                  'Guarda direcciones, edita tus datos y consulta tu historial de pedidos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.login),
                child: const Text('Iniciar Sesión o Registrarse'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // En tu archivo lib/screens/profile_screen.dart

// REEMPLAZA LA FUNCIÓN EXISTENTE CON ESTA:
  Widget _buildLoggedInScreen(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // --- SECCIÓN CORREGIDA ---
      // Nos aseguramos de que la AppBar siempre tenga el botón de logout.
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        automaticallyImplyLeading: false,
        // Correcto, no se debe poder volver atrás.
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            // Llama a la función de logout que ya tienes.
            tooltip: 'Cerrar Sesión', // Buena práctica para accesibilidad.
          ),
        ],
      ),
      // El resto del cuerpo de la pantalla no necesita cambios.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Tarjeta de bienvenida con la información del usuario
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      child: Text(
                          widget.usuario.nombre.isNotEmpty ? widget.usuario
                              .nombre[0].toUpperCase() : '?'),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.usuario.nombre,
                            style: theme.textTheme.titleLarge),
                        Text(widget.usuario.correo,
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Opciones del menú (Editar Perfil, Historial, etc.)
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar Perfil'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Navegar a la pantalla de edición de perfil
                Navigator.of(context).pushNamed(
                    AppRoutes.editProfile, arguments: widget.usuario);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Historial de Pedidos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Navegar al historial de pedidos
                Navigator.of(context).pushNamed(
                    AppRoutes.orderHistory, arguments: widget.usuario);
              },
            ),

            const SizedBox(height: 24),

            // Sección de Ubicaciones
            Text('Mis Ubicaciones', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            FutureBuilder<List<Ubicacion>>(
              future: _ubicacionesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Error al cargar las ubicaciones.'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('No tienes ubicaciones guardadas.'));
                }
                // Aquí se construye la lista de ubicaciones...
                return ListView.builder(
                  shrinkWrap: true,
                  // Importante dentro de un SingleChildScrollView
                  physics: const NeverScrollableScrollPhysics(),
                  // Evita el scroll anidado
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final ubicacion = snapshot.data![index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(ubicacion.direccion ??
                            'Dirección desconocida'),
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