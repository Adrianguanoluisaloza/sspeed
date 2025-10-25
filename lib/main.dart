import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/cart_model.dart';
import 'models/session_state.dart';
import 'services/database_service.dart';
import 'routes/app_routes.dart';
import 'routes/route_generator.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionController()),
        ChangeNotifierProvider(create: (_) => CartModel()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
      ],
      child: const MyApp(),
    ),
  );
  requestLocationPermission(); // Solicita permisos al inicio
}

Future<void> requestLocationPermission() async {
  var status = await Permission.locationWhenInUse.request();

  if (status.isGranted) {
    debugPrint("✅ Permiso de ubicación concedido");
  } else if (status.isDenied) {
    debugPrint("❌ Permiso de ubicación denegado");
  } else if (status.isPermanentlyDenied) {
    openAppSettings(); // Abre ajustes si el usuario bloqueó permisos
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryOrange = Color(0xFFFF6F3C);
    const Color accentTeal = Color(0xFF0D9488);

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryOrange,
        primary: primaryOrange,
        secondary: accentTeal,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: primaryOrange,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ), // Ajustamos a CardThemeData para cumplir con Material 3.
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        hintStyle: TextStyle(color: Colors.grey.shade500),
      ),
    );

    return MaterialApp(
      title: 'Unite7speed Delivery App',
      debugShowCheckedModeBanner: false,
      theme: theme,
      initialRoute: AppRoutes.splash,
      // Centralizamos toda la navegación para conseguir transiciones consistentes.
      onGenerateRoute: RouteGenerator.generateRoute,
    );
  }
}
