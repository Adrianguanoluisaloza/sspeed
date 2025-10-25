import 'dart:async';
import 'package:flutter/material.dart';

class TrackingSimulationScreen extends StatefulWidget {
  final int idPedido;

  const TrackingSimulationScreen({super.key, required this.idPedido});

  @override
  State<TrackingSimulationScreen> createState() => _TrackingSimulationScreenState();
}

class _TrackingSimulationScreenState extends State<TrackingSimulationScreen> {
  double _deliveryPosition = 0.0; // Posición de 0.0 a 1.0
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Iniciamos un temporizador que simula el movimiento del repartidor
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _deliveryPosition += 0.05;
        if (_deliveryPosition >= 1.0) {
          _deliveryPosition = 1.0;
          timer.cancel(); // Detiene el timer al llegar al destino
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Siguiendo Pedido #${widget.idPedido}'),
      ),
      body: Stack(
        children: [
          // 1. El "Falso Mapa" de fondo
          Container(
            color: Colors.grey[200],
            child: Center(
              child: CustomPaint(
                painter: RoutePainter(),
                size: Size.infinite,
              ),
            ),
          ),
          // 2. El icono animado del repartidor
          AnimatedPositioned(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            top: MediaQuery.of(context).size.height * 0.2,
            left: MediaQuery.of(context).size.width * 0.1 + (MediaQuery.of(context).size.width * 0.7 * _deliveryPosition),
            child: const Icon(Icons.delivery_dining, color: Colors.deepOrange, size: 40),
          ),
          // 3. Icono de la casa (destino)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.18,
            right: MediaQuery.of(context).size.width * 0.1,
            child: const Icon(Icons.home_filled, color: Colors.green, size: 45),
          ),
          // 4. Tarjeta de información
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildInfoCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final remainingTime = (1 - _deliveryPosition) * 15; // Simulación de tiempo restante
    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tu pedido está en camino!', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Repartidor:', style: TextStyle(color: Colors.grey)),
                    const Text('Carlos Mendoza', style: TextStyle(fontWeight: FontWeight.bold)), // Nombre de ejemplo
                  ],
                )
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Llegada estimada:'),
                Text(
                  _deliveryPosition >= 1.0 ? '¡Ha llegado!' : 'en ${remainingTime.ceil()} min',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Painter para dibujar una ruta simple en el "falso mapa"
class RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.25);
    path.lineTo(size.width * 0.9, size.height * 0.25);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
