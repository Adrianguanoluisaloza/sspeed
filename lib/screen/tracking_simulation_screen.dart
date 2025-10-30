import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/tracking_point.dart';
import '../services/database_service.dart';

class TrackingSimulationScreen extends StatefulWidget {
  final int idPedido;

  const TrackingSimulationScreen({super.key, required this.idPedido});

  @override
  State<TrackingSimulationScreen> createState() => _TrackingSimulationScreenState();
}

class _TrackingSimulationScreenState extends State<TrackingSimulationScreen> {
  final MapController _mapController = MapController();
  Timer? _timer;

  List<TrackingPoint> _route = const [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isPlaying = true;
  String? _error;
  double _zoomLevel = 14;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      final points = await db.getTrackingRoute(widget.idPedido);
      if (!mounted) return;

      setState(() {
        _route = points.isNotEmpty ? points : _buildFallbackRoute();
        _isLoading = false;
        _error = points.isEmpty ? 'Mostrando ruta simulada.' : null;
        _currentIndex = 0;
        _isPlaying = true;
      });

      _moveCamera(_currentLatLng, zoom: 15);
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _route = _buildFallbackRoute();
        _isLoading = false;
        _error = 'No se pudo obtener la ruta en vivo. Se muestra una simulación.';
        _currentIndex = 0;
        _isPlaying = true;
      });
      _moveCamera(_currentLatLng, zoom: 15);
      _startTimer();
    }
  }

  List<TrackingPoint> _buildFallbackRoute() {
    const fallback = <LatLng>[
      LatLng(0.970362, -79.652557),
      LatLng(0.970524, -79.655029),
      LatLng(0.976980, -79.654840),
      LatLng(0.983438, -79.655182),
      LatLng(0.984854, -79.657457),
      LatLng(0.988033, -79.659094),
    ];
    return fallback
        .asMap()
        .entries
        .map((entry) => TrackingPoint(
              latitud: entry.value.latitude,
              longitud: entry.value.longitude,
              orden: entry.key + 1,
              descripcion: 'Punto ${entry.key + 1}',
            ))
        .toList();
  }

  LatLng get _currentLatLng =>
      _route.isNotEmpty ? _route[_currentIndex.clamp(0, _route.length - 1)].toLatLng() : const LatLng(0, 0);

  List<LatLng> get _polyline => _route.map((point) => point.toLatLng()).toList();

  void _startTimer() {
    _timer?.cancel();
    if (_route.length < 2) return;

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isPlaying || !mounted) return;

      if (_currentIndex >= _route.length - 1) {
        setState(() => _isPlaying = false);
        timer.cancel();
        return;
      }

      setState(() {
        _currentIndex += 1;
      });
      _moveCamera(_currentLatLng);
    });
  }

  void _moveCamera(LatLng target, {double? zoom}) {
    if (zoom != null) {
      _zoomLevel = zoom;
    }
    _mapController.move(target, _zoomLevel);
  }

  double get _progress =>
      _route.length <= 1 ? 1 : (_currentIndex / (_route.length - 1)).clamp(0, 1).toDouble();

  int get _remainingStops => _route.isEmpty ? 0 : (_route.length - 1) - _currentIndex;

  String get _etaText {
    if (_progress >= 1) return '¡Ha llegado!';
    final minutes = (_remainingStops * 3).clamp(1, 45);
    return 'en $minutes min';
  }

  Widget _buildMap() {
    if (_route.isEmpty) {
      return const Center(child: Text('Sin puntos de referencia para mostrar.'));
    }

    final markers = <Marker>[
      Marker(
        width: 48,
        height: 48,
        point: _route.first.toLatLng(),
        child: const _MapMarker(icon: Icons.store_mall_directory, color: Colors.blueGrey),
      ),
      Marker(
        width: 54,
        height: 54,
        point: _currentLatLng,
        child: const _MapMarker(icon: Icons.delivery_dining, color: Colors.deepOrange, animate: true),
      ),
      Marker(
        width: 48,
        height: 48,
        point: _route.last.toLatLng(),
        child: const _MapMarker(icon: Icons.home_filled, color: Colors.green),
      ),
    ];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLatLng,
        initialZoom: _zoomLevel,
        maxZoom: 18,
        minZoom: 3,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.sspeed',
        ),
        if (_polyline.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(points: _polyline, color: Colors.deepOrange, strokeWidth: 4),
            ],
          ),
        MarkerLayer(markers: markers),
        const Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text('© OpenStreetMap contributors',
                style: TextStyle(fontSize: 10, color: Colors.black54)),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    final currentPoint =
        _route.isNotEmpty ? _route[_currentIndex.clamp(0, _route.length - 1)] : null;
    final percentage = (_progress * 100).clamp(0, 100).toInt();
    final nextStop = currentPoint?.descripcion;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Seguimiento en tiempo real',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progress, minHeight: 6, color: Colors.deepOrange),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estado del repartidor', style: TextStyle(color: Colors.grey)),
                    Text('${percentage.clamp(0, 100)}% completado',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Chip(
                  avatar: const Icon(Icons.timer_outlined, size: 18),
                  label: Text(_etaText, style: const TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.orange.shade100,
                ),
              ],
            ),
            if (nextStop != null && nextStop.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Próxima parada: $nextStop',
                  style: const TextStyle(fontSize: 13, color: Colors.black87)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    if (_route.length < 2) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'playPause',
          onPressed: () {
            setState(() => _isPlaying = !_isPlaying);
          },
          child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.small(
          heroTag: 'restart',
          onPressed: () {
            setState(() {
              _currentIndex = 0;
              _isPlaying = true;
            });
            _moveCamera(_currentLatLng, zoom: 15);
            _startTimer();
          },
          child: const Icon(Icons.replay),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Siguiendo Pedido #${widget.idPedido}'),
      ),
      floatingActionButton: _buildControls(),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(child: _buildMap()),
                  _buildInfoCard(),
                  const SizedBox(height: 8),
                ],
              ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool animate;

  const _MapMarker({required this.icon, required this.color, this.animate = false});

  @override
  Widget build(BuildContext context) {
    final marker = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Icon(icon, color: color, size: 26),
    );

    if (!animate) return marker;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1.08),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: marker,
    );
  }
}
