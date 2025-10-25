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
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final userEmail = prefs.getString('userEmail');
    final userPassword = prefs.getString('userPassword');

    final databaseService = context.read<DatabaseService>();
    final session = context.read<SessionController>();
    final navigator = Navigator.of(context);

    if (userEmail != null && userPassword != null) {
      try {
        final user = await databaseService.login(userEmail, userPassword);
        if (user != null && user.estaActivo) {
          session.setUser(user);
          // Si el login es exitoso, navega a la pantalla correspondiente
          _navigateForUser(user, navigator);
          return; 
        }
      } on ApiException catch (_) {
        // Si la API falla, no hacemos nada y dejamos que siga el flujo no-autenticado.
      } catch (_) {
        // Cualquier otro error, también.
      }
    }
    
    // SI NO HAY LOGIN, SIEMPRE NAVEGA A LA PANTALLA PRINCIPAL CON UN USUARIO NO AUTENTICADO
    session.clearUser();
    navigator.pushReplacementNamed(AppRoutes.mainNavigator, arguments: Usuario.noAuth());
  }

  void _navigateForUser(Usuario user, NavigatorState navigator) {
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
    navigator.pushReplacementNamed(targetRoute, arguments: user);
  }

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.delivery_dining, size: 120, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text('Unite7speed Delivery', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
