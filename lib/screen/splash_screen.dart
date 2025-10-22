import 'package:flutter/cupertino.dart' show StatefulWidget, State, BuildContext, Widget, Color, Navigator, MainAxisAlignment, Icon, SizedBox, FontWeight, TextStyle, Text, AlwaysStoppedAnimation, Column, Center;
import 'package:flutter/material.dart' show MaterialPageRoute, Scaffold, Colors, Icons, CircularProgressIndicator;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../services/database_service.dart';
import 'login_screen.dart';
import 'main_navigator.dart';

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
    // Pequeña demora para que el splash sea visible
    await Future.delayed(const Duration(seconds: 2));

    // Verifica si el widget sigue montado
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail');
    final userPassword = prefs.getString('userPassword');

    if (userEmail != null && userPassword != null) {
      // Obtenemos el servicio de base de datos
      final databaseService = Provider.of<DatabaseService>(context, listen: false);

      try {
        final user = await databaseService.login(userEmail, userPassword);

        // ⚠️ Verificamos nuevamente que el widget siga montado tras el await
        if (!mounted) return;

        if (user != null) {
          // Si el login es exitoso, navegamos a la pantalla principal
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => MainNavigator(usuario: user)),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } catch (e) {
        // En caso de error, comprobamos si el widget sigue montado
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      // Si no hay datos guardados, comprobamos antes de navegar
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Una pantalla de carga simple y elegante.
    return const Scaffold(
      backgroundColor: Colors.deepOrange,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delivery_dining, size: 120, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Unite7speed Delivery',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
