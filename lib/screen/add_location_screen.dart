
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:location/location.dart';
import 'package:provider/provider.dart';

import '../models/session_state.dart';
import '../models/ubicacion.dart';
import '../services/database_service.dart';
import '../utils/web_geolocation_stub.dart'
    if (dart.library.html) '../utils/web_geolocation_web.dart' as webgeo;

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

  static const LatLng _fallbackCenter = LatLng(0.988, -79.652);

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
      _currentLatLng = _fallbackCenter;
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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (kIsWeb) {
        // Obtener ubicacion real del navegador si es posible; fallback a centro conocido
        final pos = await webgeo.getCurrentPosition();
        if (!mounted) return;
        setState(() {
          _currentLatLng =
              pos != null ? LatLng(pos.lat, pos.lng) : _fallbackCenter;
          _isLoading = false;
        });
        return;
      }
      final serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        if (!await _locationService.requestService()) {
          throw Exception('El servicio de ubicacion esta deshabilitado.');
        }
      }

      var permission = await _locationService.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _locationService.requestPermission();
        if (permission != PermissionStatus.granted) {
          throw Exception('Permiso de ubicacion denegado.');
        }
      }

      final locationData = await _locationService.getLocation();
      if (!mounted) return;
      setState(() {
        _currentLatLng =
            LatLng(locationData.latitude!, locationData.longitude!);
        _isLoading = false;
      });
      await _reverseGeocodeCurrentLocation(); // Obtener direccion inicial
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _currentLatLng = _fallbackCenter; // Fallback to Esmeraldas
      });
    }
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final dbService = context.read<DatabaseService>();
      final result = await dbService.geocodificarDireccion(query);

      if (result != null && result['latitud'] != null && result['longitud'] != null) {
        final newLatLng = LatLng(result['latitud'], result['longitud']);
        setState(() {
          _currentLatLng = newLatLng;
          _addressController.text = result['direccion'] ?? query;
          _isLoading = false;
          _errorMessage = null;
        });
        final controller = await _mapController.future;
        await controller.animateCamera(CameraUpdate.newLatLng(newLatLng));
      } else {
        setState(() {
          _errorMessage = 'No se encontraron resultados para la direccion.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al buscar direccion: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _reverseGeocodeCurrentLocation() async {
    if (_currentLatLng == null) return;
    try {
      final lat = _currentLatLng!.latitude.toStringAsFixed(6);
      final lon = _currentLatLng!.longitude.toStringAsFixed(6);
      if (_addressController.text.trim().isEmpty) {
        _addressController.text = 'Lat: $lat, Lon: $lon';
        _searchController.text = _addressController.text;
      }
    } catch (e) {
      debugPrint('Error durante reverse geocoding: $e');
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
      Navigator.of(context).pop(true); // Devuelve true para indicar exito
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar la ubicacion: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Anadir Ubicacion' : 'Editar Ubicacion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveLocation,
          ),
        ],
      ),
      body: _currentLatLng == null
          ? Center(
              child: _errorMessage != null
                  ? Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : const CircularProgressIndicator(),
            )
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
                  onCameraMove: _onCameraMove,
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
                          labelText: 'Buscar direccion',
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
                              labelText: 'Descripcion (Ej: Casa, Oficina)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Direccion / Referencia',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _saveLocation,
                            child: const Text('Guardar ubicacion'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_errorMessage != null)
                  Positioned(
                    top: 100,
                    left: 16,
                    right: 16,
                    child: Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                if (_isLoading)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: true,
                      child: Container(
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
