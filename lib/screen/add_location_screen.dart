
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';

import '../models/session_state.dart';
import '../models/ubicacion.dart';
import '../services/database_service.dart';

class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({super.key});

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final Location _locationService = Location();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  LatLng? _currentLatLng;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        if (!await _locationService.requestService()) {
          throw Exception('El servicio de ubicación está deshabilitado.');
        }
      }

      var permission = await _locationService.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _locationService.requestPermission();
        if (permission != PermissionStatus.granted) {
          throw Exception('Permiso de ubicación denegado.');
        }
      }
      
      final locationData = await _locationService.getLocation();
      setState(() {
        _currentLatLng = LatLng(locationData.latitude!, locationData.longitude!);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _currentLatLng = const LatLng(0.988, -79.652); // Fallback to Esmeraldas
      });
    }
  }

  Future<void> _saveLocation() async {
    if (_currentLatLng == null) return;

    final dbService = context.read<DatabaseService>();
    final session = context.read<SessionController>();

    final newLocation = Ubicacion(
      idUsuario: session.usuario!.idUsuario,
      latitud: _currentLatLng!.latitude,
      longitud: _currentLatLng!.longitude,
      direccion: _addressController.text.trim(),
      descripcion: _descriptionController.text.trim(),
      activa: true,
    );

    try {
      await dbService.guardarUbicacion(newLocation);
      if (!mounted) return;
      Navigator.of(context).pop(true); // Devuelve true para indicar éxito
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar la ubicación: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir Nueva Ubicación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveLocation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _currentLatLng!,
                        zoom: 16,
                      ),
                      onMapCreated: (controller) {
                        _mapController.complete(controller);
                      },
                      onCameraMove: (position) {
                        _currentLatLng = position.target;
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                    ),
                    const Center(
                      child: Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: _descriptionController,
                                decoration: const InputDecoration(
                                  labelText: 'Descripción (Ej: Casa, Oficina)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _addressController,
                                decoration: const InputDecoration(
                                  labelText: 'Dirección / Referencia',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: _saveLocation,
                                child: const Text('Guardar Ubicación'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
