import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/ubicacion.dart';
import 'package:flutter_application_2/models/usuario.dart';
import 'package:flutter_application_2/services/database_service.dart';
import 'package:provider/provider.dart';

class UbicacionScreen extends StatefulWidget {
  final Usuario usuario;
  const UbicacionScreen({super.key, required this.usuario});

  @override
  State<UbicacionScreen> createState() => _UbicacionScreenState();
}

class _UbicacionScreenState extends State<UbicacionScreen> {
  late Future<List<Ubicacion>> _ubicacionesFuture;

  @override
  void initState() {
    super.initState();
    // ¡CAMBIO CLAVE!
    // Obtenemos la instancia de DatabaseService del Provider para llamar al método.
    _ubicacionesFuture = Provider.of<DatabaseService>(context, listen: false)
        .getUbicaciones(widget.usuario.idUsuario);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Ubicaciones'),
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
      ),
      body: FutureBuilder<List<Ubicacion>>(
        future: _ubicacionesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blue));
          }
          if (snapshot.hasError) {
            debugPrint('Error al cargar ubicaciones: ${snapshot.error}');
            return const Center(child: Text('Error al cargar las ubicaciones.'));
          }

          final ubicaciones = snapshot.data ?? [];

          if (ubicaciones.isEmpty) {
            return const Center(
              child: Text('No tienes ubicaciones registradas.'),
            );
          }

          return ListView.builder(
            itemCount: ubicaciones.length,
            itemBuilder: (context, index) {
              final ubicacion = ubicaciones[index];
              return _LocationCard(ubicacion: ubicacion);
            },
          );
        },
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final Ubicacion ubicacion;
  const _LocationCard({required this.ubicacion});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ubicacion.direccion,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Text(
              'Latitud: ${ubicacion.latitud.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            Text(
              'Longitud: ${ubicacion.longitud.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Registro: ${ubicacion.fechaRegistro.day}/${ubicacion.fechaRegistro.month}/${ubicacion.fechaRegistro.year}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
