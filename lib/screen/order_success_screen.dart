import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session_state.dart';
import '../models/usuario.dart';
import '../routes/app_routes.dart';

class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({super.key, this.usuario});

  final Usuario? usuario;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.green, size: 100),
                ),
              ),
              const SizedBox(height: 32),
              // CORRECCIÓN: Se arreglan los caracteres especiales.
              const Text(
                '¡Pedido Realizado con Éxito!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // CORRECCIÓN: Se arreglan los caracteres especiales.
              Text(
                'Gracias por tu compra. Recibirás una notificación cuando tu pedido esté en camino.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                // CORRECCIÓN: Lógica de navegación simplificada y robusta.
                onPressed: () {
                  final session = context.read<SessionController>();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.mainNavigator,
                    (route) => false,
                    arguments: session.usuario, // Se pasa el usuario de la sesión actual.
                  );
                },
                child: const Text('Volver al Inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
