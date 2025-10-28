import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // CORRECCIÓN: La navegación se ejecuta despuÃ©s de que el primer frame se haya dibujado.
    // Esto evita el error "setState() or markNeedsBuild() called during build".
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });
  }

  Future<void> _checkLoginStatus() async {
    // Lógica para comprobar si hay una sesiÃ³n activa (a implementar en el futuro)
    // Por ahora, como en tu cÃ³digo, siempre navegamos al login.
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6F3C), Color(0xFFFB923C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  // CORRECCIÓN: Se usa withAlpha con un valor entero (0-255).
                  color: Colors.white.withAlpha(31),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.delivery_dining, size: 120, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                'Unite Speed Delivery', // CORRECCIÓN: Typo
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
