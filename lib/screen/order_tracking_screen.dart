
import 'package:flutter/material.dart';

class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento de Pedido #1001'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 1. Simulación de Mapa Estático
            _buildMapPlaceholder(context),

            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Estado del Delivery',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
              ),
            ),

            // 2. Timeline del Pedido
            _buildOrderTimeline(),

            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Detalles del Repartidor',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
              ),
            ),

            // 3. Información del Delivery
            _buildDriverInfo(),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // Widget de Mapa (Simulación, ya que el tracking real es complejo)
  Widget _buildMapPlaceholder(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: const Stack(
        alignment: Alignment.center,
        children: [
          // Fondo de mapa
          Text('MAPA ESTÁTICO DE RUTA', style: TextStyle(color: Colors.black54, fontSize: 16)),

          // Icono del repartidor
          Positioned(
            top: 50,
            left: 50,
            child: Icon(Icons.motorcycle, size: 40, color: Colors.red),
          ),

          // Icono del destino
          Positioned(
            bottom: 50,
            right: 50,
            child: Icon(Icons.location_on, size: 40, color: Colors.green),
          ),
        ],
      ),
    );
  }

  // Widget de línea de tiempo del pedido
  Widget _buildOrderTimeline() {
    return const Column(
      children: [
        TimelineTile(
          icon: Icons.check_circle,
          title: 'Pedido Confirmado',
          subtitle: 'Esperando que el restaurante lo prepare.',
          isDone: true,
        ),
        TimelineTile(
          icon: Icons.restaurant_menu,
          title: 'En Preparación',
          subtitle: 'El restaurante está cocinando tu comida.',
          isDone: true,
        ),
        TimelineTile(
          icon: Icons.motorcycle,
          title: 'En Camino',
          subtitle: 'El repartidor está cerca de tu ubicación.',
          isDone: false, // Simulación: este es el estado actual
        ),
        TimelineTile(
          icon: Icons.home,
          title: 'Entregado',
          subtitle: '¡Disfruta tu pedido!',
          isDone: false,
        ),
      ],
    );
  }

  // Widget con información del repartidor
  Widget _buildDriverInfo() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundImage: NetworkImage('https://placehold.co/100x100/388e3c/ffffff?text=D'),
          backgroundColor: Colors.green,
        ),
        title: const Text('Repartidor: Daniel García'),
        subtitle: const Text('Vehículo: Moto (Placa: ABC-123)'),
        trailing: IconButton(
          icon: const Icon(Icons.phone, color: Colors.green),
          onPressed: () {
            // Simular llamada
          },
        ),
      ),
    );
  }
}

// Componente auxiliar para la línea de tiempo
class TimelineTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDone;

  const TimelineTile({super.key, required this.icon, required this.title, required this.subtitle, required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, color: isDone ? Colors.green : Colors.grey, size: 30),
              // Línea de conexión
              Container(
                width: 2,
                height: 40,
                color: isDone ? Colors.green : Colors.grey.shade300,
              ),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDone ? Colors.black : Colors.grey,
                  ),
                ),
                Text(subtitle, style: TextStyle(color: isDone ? Colors.black54 : Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
