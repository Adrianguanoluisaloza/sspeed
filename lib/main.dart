import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'models/cart_model.dart';
import 'models/session_state.dart';
import 'services/database_service.dart';
import 'services/gemini_service.dart';
import 'routes/app_routes.dart';
import 'routes/route_generator.dart';

Future<void> main() async {
  // --- INICIALIZACIÓN SEGURA ---
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es_EC';
  await initializeDateFormatting('es_EC', null);

  // --- EJECUCIÓN DE LA APP ---
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionController()),
        ChangeNotifierProvider(create: (_) => CartModel()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<GeminiService>(create: (_) => GeminiService()),
      ],
      child: const MyApp(),
    ),
  );

  // --- LÍNEA PROBLEMÁTICA ELIMINADA ---
  // unawaited(requestLocationPermission()); // <-- ESTO SE ELIMINÓ//
}

// --- FUNCIÓN PROBLEMÁTICA ELIMINADA ---
// La función 'requestLocationPermission' también se eliminó de este archivo.
// Esta lógica ahora debe vivir DENTRO de un widget (ej. la pantalla de dirección).

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
        surface: backgroundColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: 'Inter',

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
        clipBehavior: Clip.antiAlias,
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
      initialRoute: AppRoutes.splash, // Tu 'splash_screen.dart' ahora funcionará
      onGenerateRoute: RouteGenerator.generateRoute,
    );
  }
}
