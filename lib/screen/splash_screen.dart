import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session_state.dart';
import '../models/usuario.dart';
import '../services/api_exception.dart';
import '../services/database_service.dart';
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
    _checkLoginStatus();
  }
  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail');
    final userPassword = prefs.getString('userPassword');
    final databaseService = context.read<DatabaseService>();
    final session = context.read<SessionController>();

    if (userEmail != null && userPassword != null) {
      try {
        final user = await databaseService.login(userEmail, userPassword);
        if (!mounted) return;
        if (user != null && user.estaActivo) {
          session.setUser(user);
          _navigateForUser(user);
          return;
        }
      } on ApiException catch (_) {
        // Ignoramos, el flujo continuará como invitado
      } catch (_) {
        // Cualquier otro error redirige al flujo invitado
      }
    }

    if (!mounted) return;
    session.setGuest();
    _navigateAsGuest();
  }

  void _navigateForUser(Usuario user) {
    String targetRoute;
    switch (user.rol) {
      case 'admin':
        targetRoute = AppRoutes.adminHome;
        break;
      case 'delivery':
        targetRoute = AppRoutes.deliveryHome;
        break;
      default:
        targetRoute = AppRoutes.mainNavigator;
    }

    Navigator.of(context).pushReplacementNamed(targetRoute, arguments: user);
  }

  void _navigateAsGuest() {
    final guest = context.read<SessionController>().usuario;
    Navigator.of(context)
        .pushReplacementNamed(AppRoutes.mainNavigator, arguments: guest);
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
                  color: Colors.white.withValues(alpha: 0.12), // Reemplazo recomendado para evitar deprecaciones.
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.delivery_dining,
                    size: 120, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                'Unite7speed Delivery',
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

