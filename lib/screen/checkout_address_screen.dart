import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/ubicacion.dart';
import 'package:flutter_application_2/models/usuario.dart';
import 'package:flutter_application_2/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class CheckoutAddressScreen extends StatefulWidget {
  final Usuario usuario;
  const CheckoutAddressScreen({super.key, required this.usuario});

  @override
  State<CheckoutAddressScreen> createState() => _CheckoutAddressScreenState();
}

class _CheckoutAddressScreenState extends State<CheckoutAddressScreen> {
  late Future<List<Ubicacion>> _ubicacionesFuture;
  int? _selectedLocationId; // Para guardar el ID de la ubicación seleccionada

  @override
  void initState() {
    super.initState();
    _ubicacionesFuture = Provider.of<DatabaseService>(context, listen: false)
        .getUbicaciones(widget.usuario.idUsuario);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.usuario.isGuest) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Seleccionar Dirección'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline,
                    size: 96, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                const Text(
                  'Necesitas iniciar sesión para continuar',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Así podremos asociar la dirección a tus pedidos.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pushNamed('/login'),
                  child: const Text('Iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
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
                  return const Center(
                      child: Text('Error al cargar las ubicaciones.'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No tienes ubicaciones guardadas.',
                            style: TextStyle(fontSize: 18)),
                      ],
                    ),
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
    final bool isSelected = _selectedLocationId == ubicacion.id;
    return Card(
      color: isSelected ? Colors.deepOrange.shade100 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.deepOrange : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: () {
          setState(() {
            _selectedLocationId = ubicacion.id;
          });
        },
        leading: Icon(
          Icons.location_on,
          color: isSelected ? Colors.deepOrange : Colors.grey,
        ),
        title: Text(ubicacion.direccion ?? 'Dirección sin especificar',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            'Lat: ${ubicacion.latitud.toStringAsFixed(4)}, Lon: ${ubicacion.longitud.toStringAsFixed(4)}'),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Colors.deepOrange)
            : null,
      ),
    );
  }

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          // El botón solo se activa si se ha seleccionado una ubicación
          onPressed: _selectedLocationId == null
              ? null
              : () {
            // TODO: Navegar a la pantalla de resumen y pago.
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Continuando con ubicación ID: $_selectedLocationId')),
            );
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          child: const Text('Continuar al Pago'),
        ),
      ),
    );
  }

  // Widget de carga con efecto Shimmer
  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: 5,
        itemBuilder: (context, index) => Card(
          child: ListTile(
            leading: const Icon(Icons.location_on),
            title: Container(height: 16, width: 200, color: Colors.white),
            subtitle: Container(height: 14, width: 150, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

