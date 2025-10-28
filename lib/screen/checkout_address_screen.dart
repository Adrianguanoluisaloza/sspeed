import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/ubicacion.dart';
import 'package:flutter_application_2/models/usuario.dart';
import 'package:flutter_application_2/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../routes/app_routes.dart';

class CheckoutAddressScreen extends StatefulWidget {
  final Usuario usuario;
  const CheckoutAddressScreen({super.key, required this.usuario});

  @override
  State<CheckoutAddressScreen> createState() => _CheckoutAddressScreenState();
}

class _CheckoutAddressScreenState extends State<CheckoutAddressScreen> {
  late Future<List<Ubicacion>> _ubicacionesFuture;
  Ubicacion? _selectedLocation; // Guardamos el objeto Ubicacion completo

  @override
  void initState() {
    super.initState();
    // Solo cargar ubicaciones si el usuario está autenticado.
    if (widget.usuario.isAuthenticated) {
      _ubicacionesFuture = Provider.of<DatabaseService>(context, listen: false)
          .getUbicaciones(widget.usuario.idUsuario);
    }
  }

  // CORRECCIÓN: Ahora navega a la pantalla de checkout en lugar de mostrar un SnackBar.
  void _continueToPayment() {
    if (_selectedLocation != null) {
      Navigator.of(context).pushNamed(
        AppRoutes.checkout,
        arguments: {
          'usuario': widget.usuario,
          'ubicacion': _selectedLocation!,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.usuario.isAuthenticated) {
      return _buildLoggedOutView(); // No necesita contexto
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Dirección'),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Ubicacion>>(
              future: _ubicacionesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingShimmer();
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar las ubicaciones.'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No tienes ubicaciones guardadas.'),
                  );
                }

                final ubicaciones = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: ubicaciones.length,
                  itemBuilder: (context, index) {
                    final ubicacion = ubicaciones[index];
                    return _buildLocationCard(ubicacion);
                  },
                );
              },
            ),
          ),
          _buildContinueButton(),
        ],
      ),
    );
  }

  Widget _buildLocationCard(Ubicacion ubicacion) {
    final bool isSelected = _selectedLocation?.id == ubicacion.id;
    return Card(
      color: isSelected ? Colors.deepOrange.shade100 : Colors.white,
      child: ListTile(
        onTap: () => setState(() => _selectedLocation = ubicacion),
        leading: Icon(Icons.location_on, color: isSelected ? Colors.deepOrange : Colors.grey),
        title: Text(ubicacion.direccion ?? 'Dirección sin especificar', style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.deepOrange) : null,
      ),
    );
  }

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _selectedLocation == null ? null : _continueToPayment, // Llama al nuevo método
          child: const Text('Continuar al Pago'),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: 5,
        itemBuilder: (_, __) => Card(child: ListTile(title: Container(height: 20, color: Colors.white))),
      ),
    );
  }

  Widget _buildLoggedOutView() {
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar Dirección')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 96, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              const Text('Necesitas iniciar sesión para continuar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
                child: const Text('Iniciar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
