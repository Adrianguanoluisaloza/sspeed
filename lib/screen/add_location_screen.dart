
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

  static const LatLng _fallbackCenter = LatLng(0.988, -79.652);

  LatLng? _currentLatLng;
  bool _isLoading = true;
  String? _errorMessage;
  bool _myLocationAllowed = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _currentLatLng = LatLng(
        widget.initial!.latitud ?? 0.988,
        widget.initial!.longitud ?? -79.652,
      );
      _addressController.text = widget.initial!.direccion ?? '';
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _currentLatLng;
        if (target != null) {
          _reverseGeocodeLatLng(target);
        }
      });
    } else {
      _currentLatLng = _fallbackCenter;
      _initLocation();
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
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
        if (pos != null) {
          await _updateSelectedLocation(LatLng(pos.lat, pos.lng),
              animateCamera: false);
        } else {
          await _updateSelectedLocation(_fallbackCenter,
              animateCamera: false);
        }
        if (!mounted) return;
        setState(() {
          _myLocationAllowed = false;
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
      final latLng = LatLng(locationData.latitude!, locationData.longitude!);
      await _updateSelectedLocation(latLng, animateCamera: false);
      if (!mounted) return;
      setState(() {
        _myLocationAllowed = true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      await _updateSelectedLocation(_fallbackCenter, animateCamera: false);
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _myLocationAllowed = false;
      });
    }
  }

  Future<void> _reverseGeocodeLatLng(LatLng target) async {
    try {
      final lat = target.latitude.toStringAsFixed(6);
      final lon = target.longitude.toStringAsFixed(6);
      _addressController.text = 'Lat: $lat, Lon: $lon';
    } catch (e) {
      debugPrint('Error durante reverse geocoding: $e');
    }
  }

  Future<void> _updateSelectedLocation(LatLng target,
      {bool animateCamera = true}) async {
    setState(() {
      _currentLatLng = target;
    });
    await _reverseGeocodeLatLng(target);

    if (animateCamera && _mapController.isCompleted) {
      final controller = await _mapController.future;
      await controller.animateCamera(CameraUpdate.newLatLng(target));
    }
  }

  Future<void> _saveLocation() async {
    if (_currentLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un punto en el mapa antes de guardar.'),
        ),
      );
      return;
    }

    final dbService = context.read<DatabaseService>();
    final session = context.read<SessionController>();

    final newLocation = Ubicacion(
      idUsuario: session.usuario!.idUsuario,
      latitud: _currentLatLng!.latitude,
      longitud: _currentLatLng!.longitude,
      descripcion: '',
      direccion: _addressController.text.trim(),
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
                    if (!_mapController.isCompleted) {
                      _mapController.complete(controller);
                    }
                  },
                  myLocationEnabled: !kIsWeb && _myLocationAllowed,
                  myLocationButtonEnabled: !kIsWeb && _myLocationAllowed,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: true,
                  markers: _currentLatLng != null
                      ? {
                          Marker(
                            markerId: const MarkerId('selected_location'),
                            position: _currentLatLng!,
                            draggable: false,
                          ),
                        }
                      : {},
                  onTap: (pos) => _updateSelectedLocation(pos),
                ),
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Coordenadas seleccionadas',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _addressController.text,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Toca el mapa para ajustar la ubicacion.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
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
