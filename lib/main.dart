import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
  requestLocationPermission();
}

Future<void> requestLocationPermission() async {
  var status = await Permission.locationWhenInUse.request();
  if (status.isPermanentlyDenied) {
    openAppSettings();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Paleta de colores principal
    const Color primaryColor = Color(0xFFF97316); // Naranja Vibrante
    const Color accentColor = Color(0xFF1E3A8A);  // Azul Oscuro
    const Color backgroundColor = Color(0xFFF0F2F5); // Un gris muy claro

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        surface: backgroundColor, // CORRECCIÓN: 'background' renombrado a 'surface'
      ),
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: 'Inter', // Asegúrate de tener esta fuente en tu pubspec.yaml y carpeta de assets

      // Estilo de AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black26,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),

      // Estilo de Botones Elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),

      // Estilo de Tarjetas
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias, // Previene que los hijos se desborden
      ),

      // Estilo de Campos de Texto
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        prefixIconColor: primaryColor.withAlpha(179),
      ),
    );

    return MaterialApp(
      title: 'Unite7speed',
      debugShowCheckedModeBanner: false,
      theme: theme,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: RouteGenerator.generateRoute,
    );
  }
}
