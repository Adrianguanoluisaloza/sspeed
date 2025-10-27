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
                    // CORRECCIÃ“N: Se usa withAlpha en lugar de withOpacity
                    color: Colors.green.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.green, size: 100),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Â¡Pedido Realizado con Ã‰xito!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Gracias por tu compra. RecibirÃ¡s una notificaciÃ³n cuando tu pedido estÃ© en camino.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  // Utilizamos el usuario autenticado para no cerrar la sesión al volver al inicio.
                  final settingsUsuario = ModalRoute.of(context)?.settings.arguments;
                  final session = context.read<SessionController>();
                  Usuario? usuario = widget.usuario ?? (settingsUsuario is Usuario ? settingsUsuario : null);

                  if (usuario == null || usuario.isGuest) {
                    final sessionUsuario = session.usuario;
                    if (!sessionUsuario.isGuest) {
                      usuario = sessionUsuario;
                    }
                  }

                  if (usuario != null && !usuario.isGuest) {
                    session.setUser(usuario);
                  }

                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.mainNavigator,
                    (route) => false,
                    arguments: usuario ?? session.usuario,
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


