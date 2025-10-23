import 'package:flutter/material.dart';
import 'package:flutter_application_2/screen/login_screen.dart';
import 'package:flutter_application_2/screen/main_navigator.dart';
import 'package:flutter_application_2/screen/register_screen.dart';
import 'package:flutter_application_2/screen/splash_screen.dart'; // Asegúrate de tener este import
import 'package:provider/provider.dart';
import 'models/cart_model.dart';
import 'models/session_state.dart';
import 'models/usuario.dart';
import 'services/database_service.dart';

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
      cardTheme: CardTheme(
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
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
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/registro': (context) => const RegisterScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/main_navigator') {
          final usuario = settings.arguments;
          if (usuario is! Usuario) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          return MaterialPageRoute(
            builder: (_) => MainNavigator(usuario: usuario),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}

