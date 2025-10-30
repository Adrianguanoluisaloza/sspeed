
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:location/location.dart';
import 'package:provider/provider.dart';

import '../models/session_state.dart';
import '../models/ubicacion.dart';
import '../services/database_service.dart';

class AddLocationScreen extends StatefulWidget {
  final Ubicacion? initial;
  const AddLocationScreen({super.key, this.initial});

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final Location _locationService = Location();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController(); // New controller for search

  LatLng? _currentLatLng;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _debounce; // For debouncing map camera movements

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _currentLatLng = LatLng(
        widget.initial!.latitud ?? 0.988,
        widget.initial!.longitud ?? -79.652,
      );
      _addressController.text = widget.initial!.direccion ?? "";
      _descriptionController.text = widget.initial!.descripcion ?? "";
      _searchController.text = widget.initial!.direccion ?? ""; // Initialize search with initial address
      _isLoading = false;
    } else {
      _initLocation();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _addressController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      if (kIsWeb) {
        setState(() {
          _currentLatLng = const LatLng(0.988, -79.652);
          _isLoading = false;
        });
        return;
      }
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
      _reverseGeocodeCurrentLocation(); // Get initial address
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _currentLatLng = const LatLng(0.988, -79.652); // Fallback to Esmeraldas
      });
    }
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() { _isLoading = true; });
    try {
      final dbService = context.read<DatabaseService>();
      final result = await dbService.geocodificarDireccion(query);

      if (result != null && result['latitud'] != null && result['longitud'] != null) {
        final newLatLng = LatLng(result['latitud'], result['longitud']);
        setState(() {
          _currentLatLng = newLatLng;
          _addressController.text = result['direccion'] ?? query;
          _isLoading = false;
        });
        final controller = await _mapController.future;
        await controller.animateCamera(CameraUpdate.newLatLng(newLatLng));
      } else {
        setState(() {
          _errorMessage = 'No se encontraron resultados para la dirección.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al buscar dirección: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _reverseGeocodeCurrentLocation() async {
    if (_currentLatLng == null) return;
    final dbService = context.read<DatabaseService>();
    try {
      // This is a placeholder. Actual reverse geocoding would need a backend endpoint
      // or a client-side library. For now, we'll just update the address controller
      // with a generic message or leave it as is if it was manually entered.
      // If the backend has a reverse geocoding endpoint, it would be called here.
      // Example: final result = await dbService.reverseGeocodificar(lat: _currentLatLng!.latitude, lon: _currentLatLng!.longitude);
      // _addressController.text = result['address'];
    } catch (e) {
      debugPrint('Error during reverse geocoding: $e');
    }
  }

  void _onCameraMove(CameraPosition position) {
    _currentLatLng = position.target;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _reverseGeocodeCurrentLocation();
    });
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
      if (widget.initial?.id != null) { try { await dbService.deleteUbicacion(widget.initial!.id!); } catch (_) {} }
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
        title: Text(widget.initial == null ? 'Añadir Ubicación' : 'Editar Ubicación'),
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
                      onCameraMove: _onCameraMove, // Use the new onCameraMove
                      myLocationEnabled: !kIsWeb,
                      myLocationButtonEnabled: !kIsWeb,
                    ),
                    const Center(
                      child: Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: 'Buscar dirección',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: _searchAddress,
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _searchAddress(),
                          ),
                        ),
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
