import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_2/models/ubicacion.dart';
import 'package:flutter_application_2/models/usuario.dart';
import 'package:flutter_application_2/services/database_service.dart';
import '../models/session_state.dart';
import 'order_history_screen.dart'; // <-- AÑADIDO

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

  // --- Método para cerrar sesión ---
  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userEmail');
    await prefs.remove('userPassword');

    if (!mounted) return;
    context.read<SessionController>().setGuest();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
  // ---------------------------------

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
                  onPressed: () => Navigator.of(context).pushNamed('/login'),
                  child: const Text('Iniciar sesión'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/registro'),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          OrderHistoryScreen(usuario: widget.usuario),
                    ),
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
                        title: Text(ubicacion.direccion),
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
}
